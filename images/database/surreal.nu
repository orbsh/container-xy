use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /var/lib/surrealdb
        tag: surreal
    }
    | merge $context
    | build {|ctx|
        hub install -c $ctx.cache? [surrealdb]
        let port = '8000'

        conf volume [/var/lib/surrealdb]
        conf env {
            SURREAL_USER: $ctx.user
            SURREAL_PASS: $ctx.user
            SURREAL_BIND: $'0.0.0.0:($port)'
        }
        conf expose [$port]

        copy images/database/surreal/entrypoint.nu /entrypoint/surreal.nu

        conf cmd ['srv']
        conf workdir $ctx.workdir
    }
}
