#!/usr/bin/env nu
use libs/tasks.nu

if ($env.CRONFILE? | is-not-empty) {
    if ($env.CRONFILE | path exists) {
        sudo crontab $env.CRONFILE
        tasks spawn {
            tag: cron
            msg: $"load crontab : ($env.CRONFILE)"
            cmd: [sudo cron -f]
        }
    } else {
        print $"[Error] CRONFILE: ($env.CRONFILE) not found."
    }
}
