use ../info.nu

# ============================================================================
# Task Queue System - Data Flow & Invariants
# ============================================================================
# Data Flow: init → TASKSEQ → spawn append → tail -f → run → job spawn
#            wait monitors job list, any exit kills all → container restart
#
# Invariants:
#   [I1] TASKSEQ line count = total tasks to run
#   [I2] Any task exits → active jobs < total → kill all
#   [I3] $t.tag? | default "" → job spawn -d receives empty string
#
# Preconditions (guaranteed by caller/external):
#   [P1] init called only once
#   [P2] spawn called with non-empty $tasks
#   [P3] run receives valid JSON format
#   [P4] tasks start within wait's sleep interval
# ============================================================================

export def log [id] {
}

# -----------------------------------------------------------------------------
# init: Initialize task queue listener
# Data Flow: mktemp → $env.TASKSEQ → job spawn(tail -f → lines → from json → run)
# Preconditions: called once [P1]
# -----------------------------------------------------------------------------
export def --env init [
] {
    $env.TASKSEQ = mktemp -t tasks.XXXXXX
    touch $env.TASKSEQ
    job spawn {
        tail -f $env.TASKSEQ
        | lines
        | each {|x|
            $x | from json | run $in
        }
    }
}

# -----------------------------------------------------------------------------
# spawn: Submit tasks to queue
# Data Flow: $tasks → merge{grp, cts} → to json → save -a
# Preconditions: init executed, $tasks non-empty [P1, P2]
# -----------------------------------------------------------------------------
export def spawn [
    ...tasks
    --group(-g): string = 'default'
] {
    for t in $tasks {
        $t
        | merge {grp: $group, cts: (date now | format date '%FT%T%.3f')}
        | to json -r
        | $"($in)(char newline)"
        | save -a $env.TASKSEQ
    }
}

# -----------------------------------------------------------------------------
# run: Execute tasks (called by listener)
# Data Flow: $tasks(from JSON) → job spawn -d $tag
# Invariants: $t.tag? | default "" [I3], $t.cmd exists
# Preconditions: JSON format valid [P3]
# Reserved: let group, let task_id (future extension)
# -----------------------------------------------------------------------------
def run [
    ...tasks
] {
    if ($tasks | is-empty) { return }
    for t in $tasks {
        if ($t.msg? | is-not-empty) { info $t.msg }
        let group = $t.grp
        let tag = $t.tag? | default ""
        let task_id = if ($env.SPAWN_VIA_BASH? | is-empty) {
            let cmd = $t.cmd | split row -r '\s+'
            let bin = $cmd.0
            let args = $cmd | skip 1
            if ($t.polling_interval? | is-empty) {
                job spawn -d $tag {
                    run-external $bin ...$args out+err>| tee { save -f /proc/1/fd/1 }
                }
            } else {
                job spawn -d $tag {
                    loop {
                        do -i {
                            run-external $bin ...$args out+err>| tee { save -f /proc/1/fd/1 }
                        }
                        sleep $t.polling_interval
                    }
                }
            }
        } else {
            job spawn -d $tag {
                bash -c $'($t.cmd) |& tee /proc/1/fd/1'
            }
        }
    }
}

# -----------------------------------------------------------------------------
# wait: Wait for tasks (any exit kills all → container restart)
# Data Flow: lines | length → total, job list | length → active
#            active != total → kill all
# Invariants: total = expected count [I1], exit kills all [I2]
# Preconditions: tasks start within interval [P4]
# Reserved: $group parameter (future extension)
# -----------------------------------------------------------------------------
export def wait [
    --group(-g): string = 'default'
] {
    let interval = $env.CHECK_INTERVAL? | default '5sec' | into duration
    sleep $interval

    let sid = job list | where {|x| $x.tag? | is-empty} | get -o 0.id
    if ($sid | is-not-empty) {
        job kill $sid
    }

    let total = open -r $env.TASKSEQ | lines | length
    loop {
        let jl = job list
        if ($jl | length) != $total {
            for j in $jl {
                info $"kill ($j.tag?)"
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
