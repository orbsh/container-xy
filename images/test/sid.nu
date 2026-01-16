use ../../libs *

export def main [context: record = {}] {
    {
        from: 'ghcr.lizzie.fun/fj0r/io:base'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        config: {
            nushell: 'https://github.com/fj0r/nushell.git'
        }
    }
    | merge $context
    | build {|ctx|
        conf expose [22]
        conf env {
            LANG: C.UTF-8
            LC_ALL: C.UTF-8
            TIMEZONE: $ctx.timezone
            MASTER: $ctx.user
            PYTHONUNBUFFERED: x
        }
        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config
        nushell setup '/usr/local/bin' {
            user: $ctx.user
            src: $ctx.config.nushell
            dst: $xdg_config
            plugin: [query]
        }

        github install pueue websocat

        conf workdir $ctx.workdir
        conf cmd []
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/init.nu"]
    }
}
