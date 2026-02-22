use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    sync pg_duckdb {
        repo: 'duckdb/pg_duckdb'
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
                run [
                    'git clone --depth=1 https://github.com/duckdb/pg_duckdb.git'
                    'cd pg_duckdb'
                    'git submodule update --init --recursive'
                    'make -j$(nproc)'
                    'DESTDIR=/out make install'
                ]
            }

            with-mount {|new, old|
                cd ($dst.BUILDAH_WORKING_MOUNTPOINT | path join out/usr)
                cp -r * $new
            }

            buildah unmount $dst.BUILDAH_WORKING_CONTAINER
        }
    }
}
