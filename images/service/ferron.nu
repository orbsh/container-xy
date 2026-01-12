use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        let version = curl -sSL https://api.github.com/repos/ferronweb/ferron/releases
        | from json
        | get 0.name
        let url = $"https://github.com/ferronweb/ferron/releases/download/($version)/ferron-($version)-x86_64-unknown-linux-musl.zip"

        curl --retry 3 -fsSL $url -o ferron.zip
        unzip ferron.zip

        lg o origin config
        cat ferron.kdl

        with-mount {|new, old|
            mkdir opt/ferron
            cd opt/ferron
            for f in [ferron ferron-passwd ferron-yaml2kdl ferron-precompress] {
                cp ($old | path join ferron) .
            }

            r#'
            :8080 {
                root "/srv"
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save ferron.kdl

            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-extend now]

            def run-ferron [config?] {
                mut cmd = ["/opt/ferron/ferron"]
                let config = if ($config | is-empty) {
                    [--config /opt/ferron/ferron.kdl]
                } else {
                    [--config $config]
                }
                print $"(now)($config | str join ' ')"
                $cmd ++= $config
                pueue-extend default 1
                pueue add --group default -l ferron -- ($cmd | str join " ")
            }

            run-ferron $env.CONFIGFILE?
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save ($new | path join entrypoint ferron.nu)
        }

        conf cmd ['srv']
    }
}
