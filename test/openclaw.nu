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
        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu
    }
}
