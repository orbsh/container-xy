use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    sync pg_search {
        repo: 'paradedb/paradedb'
        version: ['substr 1']
    } $tags {|cx|
        {
            timezone: Asia/Shanghai
        }
        | merge $context
        | merge { from: 'scratch', tag: $cx.tag }
        | build {|ctx|
            conf workdir /
            let dst = {
                from: $"($context.image):($pgrx)"
            }
            | build --no-commit {|ctx1|
                let pg_ver = $context.pg_version_major
                run [
                    'git clone --depth=1 https://github.com/paradedb/paradedb.git /tmp/paradedb'
                    'cd /tmp/paradedb/pg_search'
                    $'cargo pgrx package --features icu --pg-config "/usr/lib/postgresql/($pg_ver)/bin/pg_config"'
                    $'mkdir -p /out/pg_search/lib/postgresql/($pg_ver)/lib'
                    $'cp ../target/release/pg_search-pg($pg_ver)/usr/lib/postgresql/($pg_ver)/lib/* /out/pg_search/lib/postgresql/($pg_ver)/lib'
                    $'mkdir -p /out/pg_search/share/postgresql/($pg_ver)/extension'
                    $'cp ../target/release/pg_search-pg($pg_ver)/usr/share/postgresql/($pg_ver)/extension/* /out/pg_search/share/postgresql/($pg_ver)/extension'
                ]
            }

            with-mount {|new, old|
                cd ($dst.BUILDAH_WORKING_MOUNTPOINT | path join out/pg_search)
                cp -r * $new
            }

            buildah unmount $dst.BUILDAH_WORKING_CONTAINER
        }
    }
}
