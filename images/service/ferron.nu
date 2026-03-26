use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /srv
        tag: ferron
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        hub install [ferron] -c $ctx.cache?

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
            use libs/tasks.nu

            def run-ferron [config?] {
                mut cmd = ["/usr/local/bin/ferron"]
                let config = if ($config | is-empty) {
                    [--config /etc/ferron.kdl]
                } else {
                    [--config $config]
                }
                $cmd ++= $config
                let cmd = $cmd | str join " "

                tasks spawn {
                    tag: ferron
                    msg: ($config | str join ' ')
                    cmd: $cmd
                }
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

        conf workdir $ctx.workdir
        conf cmd ['srv']
    }
}
