use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: zeroclaw }
    | build {|ctx|
        # pkg install [sudo cronie]
        hub install -c $ctx.cache? [zeroclaw] # lightpanda
        # with-mount {|new, old|
        #     cp -f ($old | path join images/tools/entrypoint/zeroclaw.nu) ($new | path join entrypoint/zeroclaw.nu)
        # }
        copy images/tools/entrypoint/zeroclaw.nu entrypoint/zeroclaw.nu

        conf expose [42617]
        conf cmd ['srv']
    }
}
