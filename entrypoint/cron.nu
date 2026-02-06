#!/usr/bin/env nu
use init.nu [pueue-spawn now]

if ($env.CRONFILE? | is-not-empty) {
    if ($env.CRONFILE | path exists) {
        print $"load crontab : ($env.CRONFILE)"
        sudo crontab $env.CRONFILE
        "sudo cron -f" | pueue-spawn cron
    } else {
        print $"[Error] CRONFILE: ($env.CRONFILE) not found."
    }
}
