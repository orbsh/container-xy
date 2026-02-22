use ./libs.nu *
use ../../../libs *

export def main [tags context] {
    sync pgrx {
        repo: 'pgcentralfoundation/pgrx'
        version: ['substr 1']
    } $tags {|cx|
        {
            pg_version_major: '18'
            pgrx_version: $cx.version
            from: 'postgres'
            timezone: Asia/Shanghai
        }
        | merge $context
        | merge { tag: $cx.tag }
        | build {|ctx|
            pkg update
            [
                sudo
                ca-certificates
                build-essential
                gnupg
                curl
                jq
                git
                make
                gcc
                g++
                cmake
                clang
                ninja-build
                libssl-dev
                libcurl4-openssl-dev
                liblz4-dev
                pkg-config
                postgresql-server-dev-($ctx.pg_version_major)
                tree
                rustup

                libreadline-dev zlib1g-dev flex bison libxml2-dev libxslt-dev
                libssl-dev libxml2-utils xsltproc
                pkg-config libc++-dev libc++abi-dev libglib2.0-dev
                libtinfo6 libicu-dev libstdc++-12-dev liblz4-dev
            ]
            | uniq
            | pkg install $in

            setup timezone $ctx.timezone
            setup git 'root'
            nushell setup '/usr/local' {
                user: 'root'
                xdg_config: '/root/.config'
                plugins: [query]
            }

            rust up 'root' stable

            run [
                'cargo install cargo-get'
                $'cargo install --locked cargo-pgrx --version ($ctx.pgrx_version)'
                $'cargo pgrx init --pg($ctx.pg_version_major)=/usr/lib/postgresql/($ctx.pg_version_major)/bin/pg_config'
            ]
        }
    }
}
