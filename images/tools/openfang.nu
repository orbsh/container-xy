use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: openfang }
    | build {|ctx|
        # pkg install [sudo cronie]
        hub install -c $ctx.cache? [openfang] # lightpanda
        copy images/tools/entrypoint/openfang.nu /entrypoint/openfang.nu

        conf expose [42617]
        conf cmd ['srv']
    }
}
