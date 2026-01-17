use ../../libs *

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
            PYTHONUNBUFFERED: x
        }
        pkg update
        pkg install [
            sudo attr procps htop cron tzdata
            # base-devel
            # nushell
            # dropbear
            openssh-client rsync s3fs
            tcpdump socat
            sqlite3 patch tree
            xz-utils zstd zip unzip
            lsof inetutils-ping iproute2 iptables net-tools
        ]
        setup timezone $ctx.timezone
        setup sudo

        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config
        nushell setup '/usr/local' {
            user: $ctx.user
            dst: $xdg_config
            plugin: [query]
        }

        hub install [pueue websocat]

        conf env {
            DEBUGE: ''
            PREBOOT: ''
            POSTBOOT: ''
            CRONFILE: ''
        }
        conf workdir $ctx.workdir
        conf cmd []
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/init.nu"]
    }
}
