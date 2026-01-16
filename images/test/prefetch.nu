use ../libs *

export def main [context: record = {}] {
    {
        from: 'ghcr.io/fj0r/xy:z'
        author: fj0r
        user: master
        workdir: /home/master
        rust: {
            channel: stable
        }
        image: test
    }
    | merge $context
    | build --skip-push {|ctx|
        # --debug $ctx.uptermd_addr
        rust prefetch --test $ctx.user $ctx.workdir 'buildah-test' [
        ]
    }
}
