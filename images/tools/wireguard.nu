use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /home/master
        tag: wireguard
    }
    | merge $context
    | build {|ctx|
        pkg install [
            wireguard-tools resolvconf
        ]
        hub install [
            boringtun
        ]
        conf env {
            WG_LOG_LEVEL: info
            WG_THREADS: 4
            WG_SUDO: 1
            WG_QUICK_USERSPACE_IMPLEMENTATION: boringtun-cli
        }
        with-mount {
            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-spawn now]

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

                # for i in $its {
                #     [wg-quick up $i] | str join ' ' | pueue-spawn wireguard_($i)
                # }
            }

            run-wireguard
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save -f entrypoint/wireguard.nu

            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-spawn now]

            if ($env.COREFILE? | is-not-empty) {
                let p = $env.COREFILE
                | path parse
                | get parent
                | path join zones

                $'
                . {
                    import ($p | path join *)

                    # forward . 1.1.1.1 8.8.8.8 {
                    #     policy sequential
                    #     prefer_udp
                    #     expire 10s
                    # }

                    reload 15s
                    cache 120
                    log
                }
                '
                | str trim
                | str replace -rma $'^ {4}' ''
                | save -f $env.COREFILE

                mkdir $p
                $'
                template IN A self {
                    answer "{{ .Name }} IN A 127.0.0.1"
                    fallthrough
                }

                # 1-2-3-4.ip A 1.2.3.4
                template IN A ip {
                    match (^|[.])(?P<a>[0-9]*)-(?P<b>[0-9]*)-(?P<c>[0-9]*)-(?P<d>[0-9]*)[.]ip[.]$
                    answer "{{ .Name }} 60 IN A {{ .Group.a }}.{{ .Group.b }}.{{ .Group.c }}.{{ .Group.d }}"
                    fallthrough
                }
                '
                | str trim
                | str replace -rma $'^ {4}' ''
                | save -f ($p | path join self)

                def run-coredns [] {
                    'coredns -conf $env.COREFILE' | pueue-spawn coredns
                }

                run-coredns
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save -f entrypoint/coredns.nu
        }
    }
}
