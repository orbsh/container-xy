const CWD = path self .
const CFG = path self ,.toml

export module image {
    export def pull [] {
        let cfg = open $CFG | get assets.image
        for t in $cfg.tags {
            use libs/lg.nu
            let img = ($cfg.repo):($t)
            lg o pull $img
            ^$env.CNTRCTL pull $img
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
    export def build [] {
        buildah unshare nu images/test.nu
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
        ]
        if $user {
            $flag ++= [--user 1000]
        }
        if $s3 {
            $flag ++= [
                -e 's3_pre=/srv/att,root,http://x.com,oss,test,access,secrets,nonempty'
                -e 's3_dev=/srv/att,root,http://x.com,oss,test,access,secrets,nonempty'
                -e SSH_HOSTKEY_ED25519=AAAAC3NzaC1lZDI1NTE5AAAAQNX1odF2vYCSKM1jjij7nxZgikenc2NmzPn+60QIuVBJctmdoUdXGLWexsg4QfyJkwdA9igQEHPzUoBxbSvr15c=
                -e SSH_SUDO_GROUP=wheel
                -e ed25519_root=AAAAC3NzaC1lZDI1NTE5AAAAIM7kcdz6dTumkC1PftC8dM2ZFt2f3kpRt7pAdsNGYjsI
                -e ed25519_a:1001=AAAAC3NzaC1lZDI1NTE5AAAAIM7kcdz6dTumkC1PftC8dM2ZFt2f3kpRt7pAdsNGYjsI
                -e ed25519_b:1002=AAAAC3NzaC1lZDI1NTE5AAAAIM7kcdz6dTumkC1PftC8dM2ZFt2f3kpRt7pAdsNGYjsI
                -p 2266:22
                -e CHECK_INTERVAL=($check)
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
