#!/usr/bin/env nu

use tasks.nu
use info.nu

def init [args] {
    if ($env.DEBUG? == 'true') { $env.config.show_errors = true }

    if ($env.PREBOOT? | is-not-empty) {
        info $"preboot ($env.PREBOOT)"
        nu -c $"source ($env.PREBOOT)"
    }

    const basedir = path self ..
    const info = path self info.nu
    let files = ls ($basedir | path join "*.nu" | into glob)
    | where type == file
    | get name

    if true {
        # Batch Mode
        mut script = [
            $"use ($info)"
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
        # Sequential Mode
        for file in $files {
            info $"load ($file)"
            nu $file
        }
    }

    if ($env.POSTBOOT? | is-not-empty) {
        info $"postboot ($env.POSTBOOT)"
        nu -c $"source ($env.POSTBOOT)"
    }

    info "boot completed"
}

export def --wrapped main [...args] {
    tasks init

    init $args

    if ($args | is-empty) {
        info "entering interactive mode..."
        # tasks list | to yaml | print $in
        exec nu
    } else if ($args.0 == "srv") {
        info "entering service mode, monitoring process status."
        tasks wait
        exit 1
    } else {
        info $"entering batch mode: ($args)"
        let cmd = ($args | get 0)
        let rest = ($args | drop nth 0)
        run-external $cmd ...$rest
    }
}
