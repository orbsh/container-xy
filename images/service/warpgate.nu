use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):wireguard'
        image: $context.image
        tag: 'warpgate'
    }
    | merge $context
    | build {|ctx|
        hub install [warpgate] -c $ctx.cache?

        b with-mount {
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            if not ('/data/warpgate.yaml' | path exists) {
                let passwd = (random chars -l 19)
                $passwd | save /data/passwd
                print $"setup warpgate with admin-password: ($passwd)"

                /usr/local/bin/warpgate ...[
                    unattended-setup
                    --data-path /data
                    --database-url 'sqlite:/data/db'
                    --ssh-port 12222
                    --http-port 8888
                    --mysql-port 33306
                    --record-sessions
                    --admin-password $passwd
                ]

                mv /etc/warpgate.yaml /data/warpgate.yaml
            }

            tasks spawn {
                tag: warpgate
                cmd: [
                    /usr/local/bin/warpgate
                    --config /data/warpgate.yaml
                    run
                ]
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/warpgate.nu
        }

        b with-mount {
            mkdir data/ssh-keys
            mkdir data/recordings
            mkdir data/db
        }

        b conf workdir /data
        b conf cmd ['srv']
    }
}
