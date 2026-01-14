use ../../libs *

export def main [context: record = {}] {
    {
        from: 'debian:sid-slim'
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
        pkg update
        pkg install [
            sudo attr procps htop cron tzdata
            # base-devel
            # nushell
            # dropbear
            openssh rsync s3fs
            tcpdump socat websocat
            sqlite3 patch tree
            xz-utils zstd zip unzip
            lsof inetutils-ping iproute2 iptables net-tools
            pueue # entrypoint
        ]
    }
}
