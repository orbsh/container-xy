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

        with-mount {
            r#'
            #!/usr/bin/env nu
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

            /usr/local/bin/warpgate --config /data/warpgate.yaml run
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save entrypoint/warpgate.nu
        }

        with-mount {
            mkdir data/ssh-keys
            mkdir data/recordings
            mkdir data/db
        }

        conf workdir /data
        conf cmd ['srv']
    }
}
