#!/usr/bin/env nu

export module tasks {
    def extend [group, num = 1] {
        let status = pueue status -g $group -j | from json
        let running = $status | get tasks | columns | length
        pueue parallel -g $group ($running + $num)
    }

    export def log [id] {

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
}

def init [args] {
    if ($env.DEBUG? == 'true') { $env.config.show_errors = true }

    if ($env.PREBOOT? | is-not-empty) {
        info $"preboot ($env.PREBOOT)"
        nu -c $"source ($env.PREBOOT)"
    }

    if (which pueued | is-empty) { error make {msg: "pueue not found, please install it."} }
    pueued -d

    const basedir = path self .
    const this = path self
    let files = ls ($basedir | path join "*.nu" | into glob)
    | where name != $this
    | get name

    if true {
        mut script = [
            $"use ($this) info"
            $'cd ($basedir)'
            $'$env.ENTRYPOINT_ARGS = ($args | to nuon)'
        ]
        for file in $files {
            let cmd = $"source ($file)"
            $script ++= [$"info '($cmd)'" $cmd]
        }
        $script
        | str join (char newline)
        | nu -c $in
    } else {
        for file in $files {
            info $"source ($file)"
            nu $file
        }
    }

    if ($env.POSTBOOT? | is-not-empty) {
        info $"postboot ($env.POSTBOOT)"
        nu -c $"source ($env.POSTBOOT)"
    }

    info "boot completed"
}

export def main [...args] {
    init $args

    if ($args | is-empty) {
        info "entering interactive mode..."
        exec nu
    } else if ($args.0 == "srv") {
        info "entering service mode, monitoring process status."
        use tasks
        tasks wait
        exit 1
    } else {
        info $"entering batch mode: ($args)"
        let cmd = ($args | get 0)
        let rest = ($args | drop nth 0)
        run-external $cmd ...$rest
    }
}

export def info [...msg] {
    print $"(date now | format date '%FT%T%.3f')│($msg | str join ' ')"
}
