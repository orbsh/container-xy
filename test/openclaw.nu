use ../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):openclaw'
        user: master
        workdir: /home/master/openclaw
    }
    | merge $context
    | merge { tag: openclawx }
    | build {|ctx|
        conf env {
            OPENCLAW_CONFIG_PATH: ($ctx.workdir | path join openclaw.json)
        }
        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu
    }
}
