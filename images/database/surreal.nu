use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /home/master
        tags: surreal
    }
    | merge $context
    | build {|ctx|
        hub install -c $ctx.cache? [surrealdb]
        let port = '8000'

        conf volume [/var/lib/surrealdb]
        conf env {
            SURREAL_USER: foo
            SURREAL_PASS: foo
            SURREAL_BIND: $'0.0.0.0:($port)'
        }
        conf expose [$port]

        with-mount {
            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-spawn now]

            [
                /usr/local/bin/surreal
                start -A
                ($env.SURREAL_STORE? | default rocksdb):///var/lib/surrealdb
            ]
            | str join " "
            | pueue-spawn surreal
            '#
            | str trim
            | str replace -rma '^ {12}' ''
            | save entrypoint/surreal.nu
        }
        conf cmd ['srv']
        conf workdir /data
    }
}
