use ../bx *

export def main [context: record = {}] {
    {
        from: 'ghcr.io/orbsh/xy:z'
        author: orbsh
        user: master
        workdir: /home/master
        rust: {
            channel: stable
        }
        image: test
    }
    | merge $context
    | build {|ctx|
        # --debug $ctx.uptermd_addr
        rust prefetch --test $ctx.user $ctx.workdir 'buildah-test' [
        ]
    }
}
