use ../info.nu

# ============================================================================
# Task Queue System - Data Flow & Invariants
# ============================================================================
# Data Flow: init → TASKSEQ → spawn append → tail -f → dispatch → job spawn
#            wait monitors job list, any exit kills all → container restart
#
# Invariants:
#   [I1] TASKSEQ line count = total tasks to run
#   [I2] Any task exits → active jobs < total → kill all
#   [I3] $t.tag? | default "" → job.description receives empty string
#
# Preconditions (guaranteed by caller/external):
#   [P1] init called only once
#   [P2] spawn called with non-empty $tasks
#   [P3] cmd is a list of strings, e.g. ["socat", "TCP-LISTEN:80,...", "TCP:target:80"]
#        - first element is the binary, remaining elements are arguments
#        - caller does NOT join into a string; dispatch splits bin/args directly
#        - when shell: true, elements are joined with spaces and passed to nu -c
#        - example (socat):
#            {tag: "socat_tcp_80", cmd: ["sudo", "socat", "TCP-LISTEN:80,reuseaddr,fork", "TCP:target:80"]}
#        - example (surreal):
#            {tag: "surreal", cmd: ["/usr/local/bin/surreal", "start", "--allow-all", "rocksdb:///var/lib/surrealdb"]}
#   [P4] spawn is called serially within each nu file; each nu file calls spawn at most once
#   [P5] nu files are scanned and executed serially by the outer loop
#
# Notes:
#   - job spawn returns immediately and the job is visible in job list right away;
#     there is no startup race between spawn and wait
#   - this system is intentionally simple: it is a container entrypoint, not a
#     general-purpose job scheduler; lifecycle is managed by the container runtime
#   - alternatives considered:
#       pueue: mature but adds an external dependency
#       sqlite-backed: more observable but unnecessary for this use case
#     current implementation uses only nushell built-in job management
# ============================================================================

export def log [id] {
    # Intentionally empty — placeholder for structured logging.
    # Do not remove; callers may reference this export.
}

# -----------------------------------------------------------------------------
# init: Initialize task queue listener
# Data Flow: mktemp → $env.TASKSEQ → job spawn(tail -f → lines → from json → dispatch)
# Preconditions: called once [P1]
# -----------------------------------------------------------------------------
export def --env init [] {
    $env.TASKSEQ = mktemp -t tasks.XXXXXX
    touch $env.TASKSEQ
    job spawn -d "taskseq_listener" {
        tail -f $env.TASKSEQ
        | lines
        | each {|x|
            $x | from json | dispatch $in
        }
    }
}

# -----------------------------------------------------------------------------
# spawn: Submit tasks to queue
# Data Flow: $tasks → merge{grp, cts} → to json → save -a
# Preconditions: init executed [P1], $tasks non-empty [P2],
#                called at most once per nu file [P4], files scanned serially [P5]
# -----------------------------------------------------------------------------
export def spawn [
    ...tasks
    --group(-g): string = 'default'
    --dry-run(-n)           # Print JSON lines to stdout instead of writing to queue
] {
    for t in $tasks {
        let line = $t
            | merge {grp: $group, cts: (date now | format date '%FT%T%.3f')}
            | to json -r
            | $"($in)(char newline)"
        if $dry_run {
            print $line
        } else {
            $line | save -a $env.TASKSEQ
        }
    }
}

# -----------------------------------------------------------------------------
# dispatch: Execute tasks (called by listener)
# Data Flow: $tasks (from JSON) → job spawn -d $job_desc
# Invariants: $t.tag? | default "" [I3], $t.cmd exists and is a list [P3]
# Preconditions: JSON format valid, cmd is a list of strings [P3]
# Note: $t.tag (from TASKSEQ) is mapped to job.description (via job spawn -d)
#       $t.shell (optional bool) — when true, joins cmd and runs via nu -c,
#         allowing nushell pipeline features without forking a bash process
# Reserved: _group, _task_id (intentionally kept for future extension — do not remove)
# -----------------------------------------------------------------------------
def dispatch [
    ...tasks
] {
    if ($tasks | is-empty) { return }
    for t in $tasks {
        if ($t.msg? | is-not-empty) { info $t.msg }
        # Task config 'tag' is mapped to job's 'description' field
        let _group = $t.grp
        let job_desc = $t.tag? | default ""
        let _task_id = if ($t.shell? | default false) {
            # Use nu -c to support nushell pipeline features (e.g. pipes, redirects).
            # Avoids forking an external shell process.
            let script = $t.cmd | str join " "
            if ($t.polling_interval? | is-empty) {
                job spawn -d $job_desc {
                    nu -c $script out+err>| tee { save -f /proc/1/fd/1 }
                }
            } else {
                job spawn -d $job_desc {
                    loop {
                        do -i {
                            nu -c $script out+err>| tee { save -f /proc/1/fd/1 }
                        }
                        sleep ($t.polling_interval | into duration)
                    }
                }
            }
        } else {
            let bin = $t.cmd.0
            let args = $t.cmd | skip 1
            if ($t.polling_interval? | is-empty) {
                job spawn -d $job_desc {
                    run-external $bin ...$args out+err>| tee { save -f /proc/1/fd/1 }
                }
            } else {
                job spawn -d $job_desc {
                    loop {
                        do -i {
                            run-external $bin ...$args out+err>| tee { save -f /proc/1/fd/1 }
                        }
                        sleep ($t.polling_interval | into duration)
                    }
                }
            }
        }
    }
}

# -----------------------------------------------------------------------------
# wait: Wait for tasks (any exit kills all → container restart)
# Data Flow: lines | length → total, job list | length → active
#            active != total → kill all
# Invariants: total = expected count [I1], exit kills all [I2]
# Note: job spawn is immediate — jobs appear in job list right away, no race condition.
# Reserved: $group parameter (future extension)
# -----------------------------------------------------------------------------
export def wait [
    --group(-g): string = 'default'
] {
    let interval = $env.CHECK_INTERVAL? | default '5sec' | into duration
    sleep $interval

    let sid = job list | where {|x| $x.description? | is-empty } | get -o 0.id
    if ($sid | is-not-empty) {
        info $"kill untagged job ($sid)"
        job kill $sid
    }

    let total = open -r $env.TASKSEQ | lines | length
    loop {
        # Only count user tasks, exclude taskseq_listener
        let jl = job list | where {|x| $x.description? != "taskseq_listener" }
        if ($jl | length) != $total {
            for j in $jl {
                info $"kill ($j.description?)"
                job kill $j.id
            }
            break
        }
        sleep $interval
    }
}

export def list [] {
    job list
}
