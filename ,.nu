const CWD = path self .
const CFG = path self ,.toml

export module hub {
    def cmpl-version [] {
        open ($CWD | path join hub.yaml)
        | get packages
        | columns
    }

    export def version [hub:string@cmpl-version] {
        use libs/hub.nu
        hub get-version (open hub.yaml | get packages | get $hub)
    }
}

export module action {
    export def update-nu-version [] {
        use hub
        let version = hub version nushell
        for f in (ls .github/workflows/* | get name) {
            let txt = open -r $f | lines
            let occ = $txt
            | enumerate
            | where {|x| $x.item | find 'setup-nu' | is-not-empty }
            | first
            | get index?
            if ($occ | is-not-empty) {
                $txt
                | enumerate
                | each {|x|
                    if $x.index == $occ + 2 {
                        let r = $x.item
                        | parse -r  "^(?<t>.*version: )(?<v>.+)"
                        | first
                        $"($r.t)($version)"
                    } else {
                        $x.item
                    }
                }
                | append ''
                | str join (char newline)
                | save -f $f
            }
        }
    }

    export def gen [
        --reg:string = "ghcr.io"
        --user:string = "fj0r"
        --image:string = xy
    ] {
        use hub
        let nu_ver = hub version nushell
        cd ($CWD | path join images)
        let fs = ls */*.nu
        | get name
        | where { not ($in | str starts-with test/) }
        | each { $in | path parse }
        for f in $fs {
            {
                name: branch_($f.stem),
                on: {
                    push: {
                        branches: [ $f.stem ],
                        tags: [ "v*.*.*" ]
                    },
                    workflow_dispatch: null
                },
                env: { REGISTRY: $reg, USERNAME: $user, IMAGE_NAME: $image },
                jobs: {
                    build: {
                        runs-on: ubuntu-latest,
                        if: "${{ !endsWith(github.event.head_commit.message, '~') }}",
                        permissions: {
                            contents: read,
                            packages: write
                        },
                        steps: [
                            {
                                name: "Checkout repository",
                                uses: "actions/checkout@v3",
                                with: {
                                    submodules: "true"
                                }
                            },
                            {
                                name: "Log into registry ${{ env.REGISTRY }}",
                                if: "github.event_name != 'pull_request'",
                                uses: "docker/login-action@v2",
                                with: {
                                    registry: "${{ env.REGISTRY }}",
                                    username: "${{ env.USERNAME }}",
                                    password: "${{ secrets.GHCR_TOKEN }}"
                                }
                            },
                            {
                                name: "Extract Docker metadata",
                                id: meta,
                                uses: "docker/metadata-action@v4",
                                with: {
                                    images: "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}"
                                }
                            },
                            {
                                name: "Setup Nushell",
                                uses: "hustcer/setup-nu@v3",
                                with: {
                                    version: $nu_ver
                                }
                            },
                            {
                                name: "Setup upterm session",
                                uses: "owenthereal/action-upterm@v1",
                                if: "contains(github.event.head_commit.message, '+debug')",
                                with: {
                                    upterm-server: "${{ secrets.UPTERMD_ADDR }}"
                                }
                            },
                            {
                                name: $"build ($f.stem)",
                                shell: "buildah unshare nu {0}",
                                run: (
                                    $"
                                    overlay use ${{ github.workspace }}/images/($f.parent)/($f.stem).nu as build
                                    build {
                                      author: ${{ env.USERNAME }}
                                      password: ${{ secrets.GHCR_TOKEN }}
                                      image: ${{ env.REGISTRY }}/${{ env.USERNAME }}/${{ env.IMAGE_NAME }}
                                      tags: ($f.stem)
                                    }
                                    "
                                    | str trim
                                    | str replace -rma '^ {36}' ''
                                    )
                            },
                            {
                                name: "Delete untagged ghcr",
                                uses: "Chizkiyahu/delete-untagged-ghcr-action@v3",
                                with: {
                                    token: "${{ secrets.GHCR_TOKEN }}",
                                    repository: "${{ github.repository }}",
                                    repository_owner: "${{ github.repository_owner }}",
                                    package_name: "",
                                    untagged_only: true,
                                    except_untagged_multiplatform: false,
                                    owner_type: user
                                }
                            }
                        ]
                    }
                }
            }
            | save -f ($CWD)/.github/workflows/branch_($f.stem).yaml
        }
    }
}

export module image {
    export def pull [--archive] {
        use libs/trace.nu
        let cfg = open $CFG | get assets.image
        for i in ($cfg.manifest | transpose k v) {
            mut images = []
            for j in ($i.v | transpose k v) {
                for t in $j.v {
                    let img = ($cfg.repo)/($j.k):($t)
                    trace o pull $img
                    ^$env.CNTRCTL pull $img
                    use entrypoint/init.nu now
                    let short = ($j.k):($t)
                    notify-send $"(now)($short)"
                    $images ++= [$short]
                    trace o move $short
                    ^$env.CNTRCTL tag $img $short
                    ^$env.CNTRCTL rmi $img
                }
            }
            if $archive {
                ^$env.CNTRCTL save ...$images | zstd -18 -T0
                | save -pf  $"($cfg.dest)/($i.k).tar.zst"
            }
        }
    }

    export def archive [] {
        let cfg = open $CFG | get assets.image
        let imgs = $cfg.tags
        | each {|x| ($cfg.repo):($x) }
        ^$env.CNTRCTL save ...$imgs | zstd -18 -T0 | save -f $cfg.archive
    }
}

export module test {
    def cmpl-build [] {
        glob ($env.PWD)/images/*/*.nu
        | path split
        | each { $in | last 2 | path join }
    }

    export def build [s: string@cmpl-build] {
        buildah unshare nu -c $"
            overlay use images/($s) as build
            build {
                cache: ~/Downloads
                image: test
                author: orbit
                skip_push: true
            }
            "
            | str trim
            | str replace -rma '^ {12}' ''
    }

    def cmpl-ferron [] {
        glob ($CWD)/images/service/ferron/*.kdl
        | path parse
        | get stem
    }

    export def ferron [
        config:string@cmpl-ferron
        --image(-i): string = 'xy:ferron'
    ] {
        let name = 'test-ferron'
        ^$env.CNTRCTL rm -f $name
        mut flag = [
            -it
            --name $name
            -v ($CWD)/images/service/ferron:/srv/ferron
            -e CONFIGFILE=/srv/ferron/($config).kdl
            -p 8888:8080
        ]
        ^$env.CNTRCTL run ...[
            ...$flag
            $image
        ]
    }

    export def run [
    --user(-u)
    --socat
    --s3
    --ssh
    --check: duration = 1sec
    ...args
    ] {
        let name = 'test-xy'
        ^$env.CNTRCTL rm -f $name
        mut flag = [
            -it
            --name $name
            --device /dev/fuse --privileged
            -v ($CWD)/entrypoint:/entrypoint
            --entrypoint /entrypoint/init.nu
            -e CHECK_INTERVAL=($check)
        ]
        if $user {
            $flag ++= [--user 1000]
        }
        if $ssh {
            $flag ++= [
                -e SSH_HOSTKEY_ED25519=AAAAC3NzaC1lZDI1NTE5AAAAQNX1odF2vYCSKM1jjij7nxZgikenc2NmzPn+60QIuVBJctmdoUdXGLWexsg4QfyJkwdA9igQEHPzUoBxbSvr15c=
                -e SSH_SUDO_GROUP=wheel
                -e ed25519_root=AAAAC3NzaC1lZDI1NTE5AAAAIM7kcdz6dTumkC1PftC8dM2ZFt2f3kpRt7pAdsNGYjsI
                -e ed25519_a:1001=AAAAC3NzaC1lZDI1NTE5AAAAIM7kcdz6dTumkC1PftC8dM2ZFt2f3kpRt7pAdsNGYjsI
                -e ed25519_b:1002=AAAAC3NzaC1lZDI1NTE5AAAAIM7kcdz6dTumkC1PftC8dM2ZFt2f3kpRt7pAdsNGYjsI
                -p 2266:22
            ]
        }
        if $s3 {
            $flag ++= [
                -e 's3_pre=/srv/att,root,http://x.com,oss,test,access,secrets,nonempty'
                -e 's3_dev=/srv/att,root,http://x.com,oss,test,access,secrets,nonempty'
            ]
        }
        if $socat {
            $flag ++= [
                -e tcp_123=abc:123
                -e tcp_456=abc:456
                -e udp_123=uuu:123
                -e udp_456=uuu:456
            ]
        }
        ^$env.CNTRCTL run ...[
            ...$flag
            ghcr.io/fj0r/xy:z
            ...$args
        ]
    }

}
