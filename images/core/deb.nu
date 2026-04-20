use ../../bx *

export def main [context: record = {}] {
    {
        from: 'debian:sid-slim'
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

        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config
        nushell setup '/usr/local' {
            user: $ctx.user
            xdg_config: $xdg_config
            plugins: [query]
        }

        hub install [websocat dropbear]

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
