use ../../bx *

export def main [context: record = {}] {
    $context
    | update image {|x|
        $x.image | path split | slice ..-2 | append 'assets' | path join
    }
    | merge {
        from: scratch
        tag: 'dropbear'
    }
    | build {|ctx|
        let dropbear = { from: 'debian:trixie-slim' }
        | build --no-commit {|ctx|
            pkg install [
                # curl jq ca-certificates
                # git gnupg
                build-essential
                automake autoconf
                # libz libcrypto
                libssl-dev zlib1g-dev
            ]
            let url = (
                curl --retry 3 -fsSL
                https://api.github.com/repos/mkj/dropbear/releases
                -H 'Accept: application/vnd.github.v3+json'
                | jq -r '.[0].tarball_url'
            )
            trace o {dropbear: $url}
            with-mount {
                mkdir build/dropbear
                curl -fsSL $url | tar -zxf - -C build/dropbear --strip-component=1
            }
            run [
                'cd /build/dropbear'
                'autoconf'
                'autoheader'
                './configure --enable-static'
                'make PROGRAMS="dropbear dbclient scp dropbearkey dropbearconvert"'
                'mkdir -p /target/bin'
                'mv dbclient dropbear scp dropbearkey dropbearconvert /target/bin'
            ]
            with-mount {
                cd build
                git clone --depth=1 https://github.com/openssh/openssh-portable.git
            }
            run [
                'cd /build/openssh-portable'
                'autoreconf'
                './configure'
                'make sftp-server'
                'mkdir -p /target/libexec'
                'mv sftp-server /target/libexec'
            ]
        }

        let version = with-mount {|new, old|
            cd ($dropbear.BUILDAH_WORKING_MOUNTPOINT
               | path join target
               )
            cp -r * $new
            # ./bin/dropbear -V | split row -r '\s+' | last
            # trace o -p 'image-volumes' {dropbear: $version}
        }


        buildah unmount $dropbear.BUILDAH_WORKING_CONTAINER
    }
}
