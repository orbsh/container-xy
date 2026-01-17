use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tags: mihomo }
    | build {|ctx|
        hub install -c $ctx.cache? [mihomo]
        with-mount {
            let m = [
                [country.mmdb Country.mmdb]
                geoip.dat
                geoip.db
            ]
            | each {|i|
                if ($i | describe -d).type == list {
                    {u: $i.0, f: $i.1}
                } else {
                    {u: $i, f: $i}
                }
            }
            for x in $m {
                curl --retry 3 -fsSL https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/($x.u) -o opt/($x.f)
            }

            $"
            #!/usr/bin/env nu
            use init.nu [pueue-extend now]
            for i in ($m | get f | to nuon) {
                ln -fs /opt/\($i\) /data
            }

            pueue-extend default 1
            pueue add --group default -l mihomo -- mihomo -d /data -ext-ctl 0.0.0.0:9090
            "
            | str replace -rma '^ {12}' ''
            | save entrypoint/mihomo.nu
        }

        conf expose [7890 7891 9090]
        conf cmd ['srv']
        conf workdir /data
    }

    {
        from: $'ghcr.io/sagernet/sing-box:latest'
        user: master
        workdir: /home/master
    }
    | $context
    | merge { tags: singbox }
    | build {|ctx|
    }
}
