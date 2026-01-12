#!/usr/bin/env nu

if ($env.CRONFILE? | is-not-empty) {
    if ($env.CRONFILE | path exists) {
        print $"load crontab : ($env.CRONFILE)"
        sudo crontab $env.CRONFILE
        pueue add --group default -l "cron" -- "sudo cron -f"
    } else {
        print $"[Error] CRONFILE: ($env.CRONFILE) not found."
    }
}
