use ../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):wireguard'
        user: master
        workdir: /home/master
        tag: test-wireguard
    }
    | merge $context
    | build {|ctx|
        conf env {
            WG_LOG_LEVEL: info
            WG_THREADS: 4
            WG_SUDO: 1
            WG_QUICK_USERSPACE_IMPLEMENTATION: boringtun-cli
        }
        with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            export def wg-ip [interface] {
                ip addr show $interface
                | lines
                | slice 1..
                | where { $in | str contains wg0 }
                | first
                | split row -r '\s+'
            }

            def run-wireguard [] {
                cd /etc/wireguard
                let its = ls *.conf
                | get name
                | each {|x| $x | path parse | get stem }

                for i in $its {
                    wg-quick up $i
                    print $"==> wg entrypoint: ($i)"
                }

                # $its | each {|i|
                #     {
                #         tag: $"wireguard_($i)"
                #         cmd: ([wg-quick up $i] | str join ' ')
                #     }
                # }
                # | tasks spawn ...$in
            }

            # run-wireguard
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save -f entrypoint/wireguard.nu
        }
    }
}
