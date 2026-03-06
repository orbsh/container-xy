use ../bx *

export def main [context: record = {}] {
    {
        from: 'ghcr.lizzie.fun/fj0r/io:base'
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
        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config
        nushell setup '/usr/local' -c $ctx.cache? {
            user: $ctx.user
            xdg_config: $xdg_config
            plugins: [query]
        }

        hub install -c $ctx.cache [websocat]

        conf workdir $ctx.workdir
        conf cmd []
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/libs/init.nu"]
    }
}
