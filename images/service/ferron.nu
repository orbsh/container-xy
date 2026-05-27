use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
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

            let cmd = [
                /usr/local/bin/ferron
                --config
                ($env.CONFIGFILE? | default /etc/ferron.kdl)
            ]

            tasks spawn {
                tag: ferron
                msg: ($cmd | str join " ")
                cmd: $cmd
            }
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
        }

        conf workdir $ctx.workdir
        conf cmd ['srv']
    }
}
