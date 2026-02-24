use ../info.nu

export def log [id] {
}

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

def run [
    ...tasks
] {
    if ($tasks | is-empty) { return }
    for t in $tasks {
        if ($t.msg? | is-not-empty) { info $t.msg }
        let group = $t.grp
        let task_id = if false {
            job spawn -t $t.tag {
                nu -c $'($t.cmd) out+err>| tee { save -f /proc/1/fd/1 }'
            }
        } else {
            job spawn -t $t.tag {
                bash -c $'($t.cmd) |& tee /proc/1/fd/1'
            }
        }
    }
}

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
