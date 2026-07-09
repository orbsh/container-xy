use ../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):openclaw'
        user: master
        workdir: /app/data
    }
    | merge $context
    | merge { tag: openclawx }
    | build {|ctx|
        b copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu
    }
}
