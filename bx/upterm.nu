export def main [server?] {
    let url = 'https://github.com/owenthereal/upterm/releases/download/v0.21.1/upterm_linux_amd64.tar.gz'
    curl -sSL $url | tar -zxf - -C /usr/local/bin upterm
    run-upterm $server
}

export def run-upterm [server?] {
    let server_arg = if ($server | is-empty) { [] } else { [--server $server] }
    # Define an admin socket path to allow 'session current' to connect

    print $"pwd=(pwd) server=($server)"
    print "Initializing upterm session..."

    if not ('~/.ssh' | path exists) { mkdir ~/.ssh }
    if not ('~/.ssh/id_ed25519' | path exists) {
        ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
    }

    let info = ^upterm ...[host ...$server_arg --skip-host-key-check --accept --force-command nu -- /usr/bin/env nu] | complete
    print "Background process started."

    if ($info.exit_code == 0) {
        # Parse the SSH connection string from stdout
        let matches = ($info.stdout | lines | where $it =~ "SSH:" | first? | str replace "SSH:" "" | str trim)
        if ($matches != null and ($matches | is-not-empty)) {
            print "****** UPTERM CONNECTION INFO ******"
            print $"SSH Command: ($matches)"
            print "************************************"

            print "Session is active. Waiting for 1 hour..."
            sleep 1hr
        }
    } else {
        print "Timeout: Could not retrieve upterm session info."
        print $"Error: ($info.stderr)"
    }
}
