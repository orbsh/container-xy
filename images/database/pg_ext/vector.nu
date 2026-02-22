use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    let version = curl --retry 3 -fsSL https://api.github.com/repos/pgvector/pgvector/tags
    | from json
    | first
    | get name
    | str substring 1..
    let tag = $"pg_vector_($version)"
    if ($tag not-in $tags) {
        {
            timezone: Asia/Shanghai
        }
        | merge $context
        | merge { from: 'scratch', tag: $tag }
        | build {|ctx|
            conf workdir /app
            let dst = {
                from: $"($context.image):($pgrx)"
            }
            | build --no-commit {|ctx1|
                run [
                    $'curl --retry 3 -fsSL https://github.com/pgvector/pgvector/archive/refs/tags/v($version).tar.gz | tar zxf - -C . --strip-components=1'
                    'make clean -j'
                    'make USE_PGXS=1 OPTFLAGS="" -j'
                    $'mkdir -p /out/lib/postgresql/($context.pg_version_major)/lib'
                    $'cp *.so /out/lib/postgresql/($context.pg_version_major)/lib'
                    $'mkdir -p /out/share/postgresql/($context.pg_version_major)/extension'
                    $'cp *.control /out/share/postgresql/($context.pg_version_major)/extension'
                    $'cp sql/*.sql /out/share/postgresql/($context.pg_version_major)/extension'
                ]
            }

            with-mount {|new, old|
                cd ($dst.BUILDAH_WORKING_MOUNTPOINT | path join out)
                cp -r * $new
            }

            buildah unmount $dst.BUILDAH_WORKING_CONTAINER
        }
    } else {
        trace o $tag exists
    }
    return $tag
}
