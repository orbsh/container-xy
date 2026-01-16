use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
        tags: ferron
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        github install [ferron] -c $ctx.cache?

        with-mount {|new, old|
            r#'
            :8080 {
                root "/srv"
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save etc/ferron.kdl
        }

        with-mount {
            cd entrypoint
            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-extend now]

            def run-ferron [config?] {
                mut cmd = ["/usr/local/bin/ferron"]
                let config = if ($config | is-empty) {
                    [--config /etc/ferron.kdl]
                } else {
                    [--config $config]
                }
                print $"(now)($config | str join ' ')"
                $cmd ++= $config
                pueue-extend default 1
                pueue add --group default -l ferron -- ($cmd | str join " ")
            }

            run-ferron $env.CONFIGFILE?
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save ferron.nu
        }

        with-mount {
            cd srv
            mkdir bin box install ferron
        }

        copy images/service/ferron /srv/ferron

        conf env {
            CONFIGFILE: /srv/ferron/box.kdl
            WEBHOOK_URI: ''
        }

        conf cmd ['srv']
    }
}
