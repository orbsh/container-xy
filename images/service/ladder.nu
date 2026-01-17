use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
        tags: mihomo
    }
    | merge $context
    | build {|ctx|
        hub install -c $ctx.cache? [mihomo]
        with-mount {
            let m = [
                [country.mmdb Country.mmdb]
                geoip.dat
                geoip.db
                cn_domain.yaml
            ]
            | each {|i|
                if ($i | describe -d).type == list {
                    {u: $i.0, f: $i.1}
                } else {
                    {u: $i, f: $i}
                }
            }
            for x in $m {
                if ($ctx.cache | is-empty) {
                    curl --retry 3 -fsSL https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/($x.u) -o opt/($x.f)
                }
            }
        }

        r#'
        #!/usr/bin/env nu
        use init.nu [pueue-extend now]
        for i in ($m | get f | to nuon) {
            if ($ctx.cache | is-empty) {
                ln -fs /opt/($i) /data
            }
        }

        pueue-extend default 1
        pueue add --group default -l mihomo -- mihomo -d /data -ext-ctl 0.0.0.0:9090
        '#

        conf expose [7890 7891 9090]
        conf cmd ['srv']
        conf workdir /data
    }
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
        tags: singbox
    }
    | merge $context
    | build {|ctx|
    }
}
