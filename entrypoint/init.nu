#!/usr/bin/env nu

def init [] {
    if ($env.DEBUG? == 'true') { $env.config.show_errors = true }

    if ($env.PREBOOT? | is-not-empty) {
        print $"(now) preboot ($env.PREBOOT)"
        nu -c $"source ($env.PREBOOT)"
    }

    if (which pueued | is-empty) { error make {msg: "pueue not found, please install it."} }
    pueued -d

    const basedir = path self .
    let files = ls ($basedir | path join "*.nu" | into glob)
    | where name != $env.CURRENT_FILE
    | get name

    if true {
        mut script = [
            "def begin [f] { print $\"[(date now | format date '%FT%T%.3f')] source ($f)\" }"
            $'cd ($basedir)'
        ]
        for file in $files {
            $script ++= [$"begin ($file)" $"source ($file)"]
        }
        $script
        | str join (char newline)
        | nu -c $in
    } else {
        for file in $files {
            print $"(now) source ($file)"
            nu $file
        }
    }

    if ($env.POSTBOOT? | is-not-empty) {
        print $"(now) postboot ($env.POSTBOOT)"
        nu -c $"source ($env.POSTBOOT)"
    }

    print $"(now) boot completed"
}

export def main [...args] {
    init

    if ($args | is-empty) {
        print $"(now) entering interactive mode..."
        exec nu
    } else if ($args.0 == "srv") {
        let g = 'default'
        let interval = $env.CHECK_INTERVAL? | default '5sec' | into duration
        print $"(now) entering service mode, monitoring process status."

        mut finished = []
        loop {
            $finished = ^pueue status --json -g $g
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
            | where group == $g and status == "Done"

            if ($finished | length) > 0 {
                print $"(now) detected a task has exited!"
                $finished
                | insert output {|x|
                    pueue log $x.id -j | from json | values | get output
                }
                | print ($in | to yaml)
                pueue kill --group $g
                break
            }
            sleep $interval
        }
        exit 1
    } else {
        print $"(now) entering batch mode: ($args)"
        let cmd = ($args | get 0)
        let rest = ($args | drop nth 0)
        run-external $cmd ...$rest
    }
}

export def pueue-extend [group, num = 1] {
    let status = pueue status -g $group -j | from json
    let running = $status | get tasks | columns | length
    pueue parallel -g $group ($running + $num)
}

export def now [] {
    $"[(date now | format date '%FT%T%.3f')]"
}
