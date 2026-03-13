use ../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):openclaw'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: openclawx }
    | build {|ctx|
        run ['rm -rf openclaw/node_modules/@node-llama-cpp']
        conf env {
            OPENCLAW_HOME: /home/master/openclaw
        }
        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu
    }
}
