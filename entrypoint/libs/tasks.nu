def extend [group, num = 1] {
    let status = pueue status -g $group -j | from json
    let running = $status | get tasks | columns | length
    pueue parallel -g $group ($running + $num)
}

export def log [id] {
    pueue log $id --json | from json
}

export def init [] {
    if (which pueued | is-empty) { error make {msg: "pueue not found, please install it."} }
    pueued -d
}

export def spawn [
    ...tasks
    --group(-g): string = 'default'
] {
    if ($tasks | is-empty) { return }
    extend $group ($tasks | length)
    for t in $tasks {
        if ($t.msg | is-not-empty) { info $t.msg }
        if false {
            pueue add --group $group -l $t.tag -- $"nu -c '($t.cmd) out+err>| tee { save -f /proc/1/fd/1 }'"
        } else {
            pueue add --group $group -l $t.tag -- $"bash -c '($t.cmd) |& tee /proc/1/fd/1'"
        }
    }
}

export def wait [
    --group(-g): string = 'default'
] {
    let interval = $env.CHECK_INTERVAL? | default '5sec' | into duration
    # :TODO: wait for https://github.com/Nukesor/pueue/issues/614
    # pueue follow --group default
    mut finished = []
    loop {
        $finished = ^pueue status --json -g $group
        | from json
        | get tasks
        | values
        | each {|x|
            {
                id: $x.id
                group: $x.group
                label: $x.label
                status: ($x.status | columns | first)
            }
        }
        | where group == $group and status == "Done"

        if ($finished | length) > 0 {
            info "detected a task has exited!"
            $finished
            | insert output {|x|
                pueue log $x.id -j | from json | values | get output
            }
            | print ($in | to yaml)
            pueue kill --group $group
            break
        }
        sleep $interval
    }
}
