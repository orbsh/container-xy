use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    sync pg_textsearch {
        repo: 'timescale/pg_textsearch'
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
                    $'curl -sSL https://github.com/timescale/pg_textsearch/releases/download/v($cx.version)/pg_textsearch-($cx.version).tar.gz | tar -zxf - -C . --strip-component=1'
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
