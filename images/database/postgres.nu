use ../../bx *
use ./pg_ext


export def main [context: record = {}] {
    let context = $context | merge {
        pg_version_major: '18'
    }

    let repo = $context.image
    | split row '/'
    | slice 1..
    | str join '/'

    let tags = ghcr tags $repo

    {
        from: 'postgres'
        timezone: Asia/Shanghai
        workdir: /var/lib/postgresql
    }
    | merge $context
    | update from {|x| $'postgres:($x.pg_version_major)' }
    | build {|ctx|

        setup timezone $ctx.timezone
        conf env {
            LANG: C.UTF-8
            LC_ALL: C.UTF-8
            TIMEZONE: $ctx.timezone
        }

        pkg refresh
        let pg_pkgs = [
            pgxnclient
            postgresql-plpython3-{version}
            postgresql-{version}-repack
            postgresql-{version}-wal2json
            postgresql-{version}-rational
            postgresql-{version}-cron
            postgresql-{version}-extra-window-functions
            postgresql-{version}-first-last-agg
            postgresql-{version}-ip4r
            postgresql-{version}-jsquery
            postgresql-{version}-pgaudit
        ]
        | each {|x|
            {version: $ctx.pg_version_major} | format pattern $x
        }
        pkg install [
            sudo attr procps htop cron
            curl libcurl4 ca-certificates uuid
            openssh-client rsync s3fs
            strace tcpdump socat
            jq sqlite3 patch tree
            xz-utils zstd zip unzip
            lsof inetutils-ping iproute2 net-tools
            nftables iptables
            ...$pg_pkgs
        ]

        nushell setup '/usr/local' {
            user: root
            xdg_config: '/root/.config'
            plugins: [query]
        }

        pkg setup py --stack [
            data http utils
        ] [
            'psycopg[binary]'
            zstandard
        ]

        conf env {
            POSTGRES_USER: master
            POSTGRES_DB: default
            POSTGRES_PASSWORD: master

            # PGCONF_IO_METHOD: worker # io_uring
            PGCONF_EFFECTIVE_CACHE_SIZE: '8GB'
            PGCONF_EFFECTIVE_IO_CONCURRENCY: 200
            PGCONF_RANDOM_PAGE_COST: 1.1
            PGCONF_WAL_LEVEL: logical
            PGCONF_MAX_REPLICATION_SLOTS: 10

            # ,citus,timescaledb
            PGQONF_SHARED_PRELOAD_LIBRARIES: 'pg_stat_statements,pg_duckdb,vector,pg_cron'
            PGCONF_LOG_MIN_DURATION_STATEMENT: 1000
            PARADEDB_TELEMETRY: 'false'
        }

        let xctx = { tags: $tags, context: $context }
        | insert pgrx {|x| pg_ext pgrx $x }

        for ext in [
            (pg_ext duckdb $xctx)
            (pg_ext vector $xctx)
            (pg_ext search $xctx)
            (pg_ext zhparser $xctx)
        ] {
            with-mount {|new, old|
                let ctr = { from: $'($context.image):($ext)' } | build --no-commit {|| }
                cd ($ctr.BUILDAH_WORKING_MOUNTPOINT)
                cp -r * ($new | path join usr)
                buildah unmount $ctr.BUILDAH_WORKING_CONTAINER
            }
        }

        for f in [extend hook] {
            copy images/database/postgres/entrypoint-($f).nu /usr/local/bin/entrypoint-($f).nu
        }

        conf workdir $ctx.workdir
        conf entrypoint [nu /usr/local/bin/entrypoint-hook.nu]
    }
}
