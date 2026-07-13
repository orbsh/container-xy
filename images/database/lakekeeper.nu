use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /var/lib/lakekeeper
    }
    | merge $context
    | build {|ctx|

        hub install -c $ctx.cache? [lakekeeper]

        b conf env {
            LAKEKEEPER__PG_ENCRYPTION_KEY: 'This-is-NOT-Secure!'
            LAKEKEEPER__AUTHZ_BACKEND: allowall
        }

        b copy images/database/lakekeeper/entrypoint.nu /entrypoint/lakekeeper.nu

        b conf volume [$ctx.workdir]
        b conf expose ['8181']
        b conf cmd ['srv']
        b conf workdir $ctx.workdir
    }
}
