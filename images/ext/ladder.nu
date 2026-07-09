use ../../bx *

export def main [context: record = {}] {
    {
        from: 'ghcr.io/sagernet/sing-box:latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: singbox }
    | build {|ctx|
    }

    {
        from: $'($context.image):deb'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: mihomo }
    | build {|ctx|
        hub install -c $ctx.cache? [mihomo]
        b with-mount {
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

            let tmpl = r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            for i in {files} {{
                ln -fs /opt/($i) /data
            }}

            tasks spawn {{
                tag: mihomo
                cmd: [mihomo -d /data -ext-ctl 0.0.0.0:9090]
            }}
            '#
            | str trim
            | str replace -rma '^ {12}' ''

            { files: ($m | get f | to nuon) }
            | format pattern $tmpl
            | save entrypoint/mihomo.nu
        }

        b conf expose [7890 7891 9090]
        b conf cmd ['srv']
        b conf workdir /data
    }
}
