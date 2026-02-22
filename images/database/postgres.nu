use ../../libs *
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

    let pgrx = pg_ext pgrx $tags $context

    let pg_duckdb = pg_ext duckdb $pgrx $tags $context

    let pg_vector = pg_ext vector $pgrx $tags $context

    # let pg_search = pg_ext search $pgrx $tags $context

    {
        from: 'postgres'
        timezone: Asia/Shanghai
        workdir: /home/master
    }
    | merge $context
    | update from {|x| $'postgres:($x.pg_version_major)' }
    | build {|ctx|

        setup timezone $ctx.timezone
        conf env {
            LANG: C.UTF-8
            LC_ALL: C.UTF-8
            TIMEZONE: $ctx.timezone
            PYTHONUNBUFFERED: x
        }

        pkg update
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

        pkg setup python [
            'psycopg[binary]'
            numpy polars httpx pyyaml
            PyParsing
            boltons decorator
        ]

        conf env {
            POSTGRES_USER: master
            POSTGRES_DB: default
            POSTGRES_PASSWORD: master

            PGCONF_IO_METHOD: worker # io_uring
            PGCONF_EFFECTIVE_CACHE_SIZE: '8GB'
            PGCONF_EFFECTIVE_IO_CONCURRENCY: 200
            PGCONF_RANDOM_PAGE_COST: 1.1
            PGCONF_WAL_LEVEL: logical
            PGCONF_MAX_REPLICATION_SLOTS: 10

            # ,citus,timescaledb
            PGCONF_SHARED_PRELOAD_LIBRARIES: "'pg_stat_statements,pg_net,pg_cron,pg_duckdb'"
            PGCONF_LOG_MIN_DURATION_STATEMENT: 1000
            PARADEDB_TELEMETRY: 'false'
        }

        for ext in [$pg_vector $pg_duckdb] {
            with-mount {|new, old|
                let ctr = { from: $'($context.image):($pg_vector)' } | build --no-commit {|| }
                cd ($ctr.BUILDAH_WORKING_MOUNTPOINT)
                cp -r * ($new | path join usr)
                buildah unmount $ctr.BUILDAH_WORKING_CONTAINER
            }
        }

        for f in [extend hook] {
            copy images/database/postgres/entrypoint-($f).nu /usr/local/bin/entrypoint-($f).nu
        }

        conf entrypoint [nu /usr/local/bin/entrypoint-hook.nu]

        # pkg with [
        #     git
        #     cmake
        #     binutils
        #     m4
        #     pkg-config
        #     lsb-release
        #     libcurl4-openssl-dev
        #     libicu-dev
        #     uuid-dev
        #     build-essential
        #     libpq-dev
        #     python3-dev
        #     libkrb5-dev
        #     postgresql-server-dev-($ctx.pg_version_major)
        # ] {
        # }

        # run [
        #     r#'mkdir /tmp/paradedb'#
        #     r#'cd /tmp/paradedb'#
        #     r#'code_name=$(cat /etc/os-release | grep '^VERSION_CODENAME' | cut -d '=' -f 2)'#
        #     r#'version=$(curl --retry 3 -fsSL -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/paradedb/paradedb/releases | jq -r '.[0].tag_name' | cut -c 2-)'#
        #     r#'curl --retry 3 -fsSL https://github.com/paradedb/paradedb/releases/download/v${version}/postgresql-${PG_VERSION_MAJOR}-pg-search_${version}-1PARADEDB-${code_name}_amd64.deb -o pg-search.deb'#
        #     r#'dpkg -i pg-search.deb'#
        #     r#'cd /tmp'#
        #     r#'rm -rf paradedb'#
        # ]


    }
}
