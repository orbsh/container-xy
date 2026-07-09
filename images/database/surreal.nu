use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /var/lib/surrealdb
        tag: surreal
    }
    | merge $context
    | build {|ctx|
        hub install -c $ctx.cache? [surrealdb]
        let port = '8000'

        b conf volume [/var/lib/surrealdb]
        b conf env {
            SURREAL_USER: $ctx.user
            SURREAL_PASS: $ctx.user
            SURREAL_BIND: $'0.0.0.0:($port)'
        }
        b conf expose [$port]

        b copy images/database/surreal/entrypoint.nu /entrypoint/surreal.nu

        b conf cmd ['srv']
        b conf workdir $ctx.workdir
    }
}
