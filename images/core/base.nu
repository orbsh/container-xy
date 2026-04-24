use ../../bx *

export def main [context: record = {}] {
    {
        from: 'archlinux'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        conf expose [22]
        conf env {
            LANG: C.UTF-8
            LC_ALL: C.UTF-8
            TIMEZONE: $ctx.timezone
            MASTER: $ctx.user
        }
        pkg refresh
        pkg install --stack [
            base dev ssh net db s3
            diag file archive network-tools
        ]
        setup timezone $ctx.timezone
        setup sudo

        setup git $ctx.author
        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config

        nushell setup '/usr/local' {
            user: $ctx.user
            xdg_config: $xdg_config
            plugins: [query]
        }

        # hub install --user $ctx.user -A $ctx.author [ duckdb ]

        pkg setup py --stack [
            web dev io cli utils logging data codec
        ]
        pkg setup js --stack [
            dev utils
        ]

        # conf volume [$ctx.workdir]
        conf env {
            DEBUGE: ''
            PREBOOT: ''
            POSTBOOT: ''
            CRONFILE: ''
        }
        conf workdir $ctx.workdir
        conf cmd []
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/libs/init.nu"]
    }
}
