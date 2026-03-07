use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):playwright'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: openfang }
    | build {|ctx|
        # pkg install [sudo cronie]

        hub install -c $ctx.cache? [openfang] # lightpanda
        copy images/tools/entrypoint/openfang.nu /entrypoint/openfang.nu

        conf expose [4200]
        conf cmd ['srv']
    }
}
