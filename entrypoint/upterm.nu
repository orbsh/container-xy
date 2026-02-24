#!/usr/bin/env nu

# $env.UPTERM_SERVER
# $env.UPTERM_WEBHOOK
# $env.UPTERM_LABELS

use libs/info.nu
use libs/tasks.nu

if ($env.UPTERM_WEBHOOK? | is-not-empty) {
    run-upterm
}

def main [] {
    if (which upterm | is-empty) {
        info $"Skipping Upterm: binary not found"
        return
    }

    info $"Initializing Upterm service..."

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

    let cmd_str = (["upterm" ...$upterm_args] | str join " ")
    let add_result = tasks spawn { cmd: $cmd_str, tag: "upterm_host"}  | complete

    if $add_result.exit_code != 0 {
        info $"Error: Failed to add task: ($add_result.stderr)"
        return
    }

    let job_id = $add_result.stdout | parse -r 'New task added \(id (?<id>[0-9]+)\)' | get 0.id
    info $"Upterm task added with ID: ($job_id)"

    job spawn {
        mut connection_str = ""
        for i in 1..15 {
            sleep 2sec

            let job_log = tasks log $job_id | get -o $job_id
            if 'Running' not-in $job_log.task.status {
                info $"Upterm process failed. Last logs:\n($job_log.output)"
                return
            }
            let matches = ($job_log.output | lines | where $it =~ "SSH:" | first? | str replace "SSH:" "" | str trim)
            if ($matches != null and ($matches | is-not-empty)) {
                $connection_str = $matches
                break
            }
        }

        if ($connection_str | is-empty) {
            info $"Upterm Error: Failed to retrieve session address"
            return
        }

        info $"Upterm Ready: ($connection_str)"

        if ($env.UPTERM_WEBHOOK? | is-not-empty) {
            let payload = {
                msg_type: "text",
                content: {
                    text: $"Container remote debugging enabled\nHostname: (hostname)\nCommand: ($connection_str)"
                }
            }

            try {
                http post -t application/json $env.UPTERM_WEBHOOK $payload
                info $"Upterm Webhook sent successfully"
            } catch {
                info $"Upterm Webhook failed to send"
            }
        }
    }
}
