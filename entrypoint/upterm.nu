#!/usr/bin/env nu

# $env.UPTERM_SERVER
# $env.UPTERM_WEBHOOK
# $env.UPTERM_LABELS

use init.nu [pueue-extend now]

if ($env.UPTERM_WEBHOOK? | is-not-empty) {
    run-upterm
}

def main [] {
    if (which upterm | is-empty) {
        print $"Skipping Upterm: binary not found"
        return
    }

    print $"(now)Initializing Upterm service..."

    let server_arg = if ($env.UPTERM_SERVER? | is-not-empty) {
        ["--server" $env.UPTERM_SERVER]
    } else {
        []
    }

    if not ('~/.ssh' | path exists) { mkdir ~/.ssh }
    if not ('~/.ssh/id_ed25519' | path exists) {
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    }

    let upterm_args = [host ...$server_arg --skip-host-key-check --accept --force-command nu -- /usr/bin/env nu]

    pueue-extend default 1
    let cmd_str = (["upterm" ...$upterm_args] | str join " ")
    let add_result = pueue add --group default -l "upterm_host" -- $cmd_str | complete

    if $add_result.exit_code != 0 {
        print $"(now)Error: Failed to add task to Pueue: ($add_result.stderr)"
        return
    }

    let job_id = $add_result.stdout | parse -r 'New task added \(id (?<id>[0-9]+)\)' | get 0.id
    print $"(now)Upterm task added to Pueue with ID: ($job_id)"

    job spawn {
        mut connection_str = ""
        for i in 1..15 {
            sleep 2sec

            let job_log = pueue log $job_id --json | from json | get $job_id
            if 'Running' not-in $job_log.task.status {
                print $"(now)Upterm process failed. Last logs:\n($job_log.output)"
                return
            }
            let matches = ($job_log.output | lines | where $it =~ "SSH:" | first? | str replace "SSH:" "" | str trim)
            if ($matches != null and ($matches | is-not-empty)) {
                $connection_str = $matches
                break
            }
        }

        if ($connection_str | is-empty) {
            print $"(now)Upterm Error: Failed to retrieve session address"
            return
        }

        print $"(now)Upterm Ready: ($connection_str)"

        if ($env.UPTERM_WEBHOOK? | is-not-empty) {
            let payload = {
                msg_type: "text",
                content: {
                    text: $"(now)Container remote debugging enabled\nHostname: (hostname)\nCommand: ($connection_str)"
                }
            }

            try {
                http post -t application/json $env.UPTERM_WEBHOOK $payload
                print $"(now)Upterm Webhook sent successfully"
            } catch {
                print $"(now)Upterm Webhook failed to send"
            }
        }
    }
}
