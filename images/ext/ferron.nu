use ../../libs *

export def main [context: record = {}] {
    {
        from: 'ghcr.io/fj0r/xy:latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        let version = http get https://api.github.com/repos/ferronweb/ferron/releases
        | get 0.name
        let url = $"https://github.com/ferronweb/ferron/releases/download/($version)/ferron-($version)-x86_64-unknown-linux-musl.zip"

        curl --retry 3 -fsSL $url -o ferron.zip
        unzip ferron.zip
        with-mount {|new, old|
            mkdir opt/ferron
            cd opt/ferron
            cp ($old | path join ferron) .
            chmod +x ferron

            '
            :8080 {
                root "/srv"
            }
            '
            | str trim
            | str replace -rma $'^\s{12}' ''
            | save ferron.kdl

            '
            #!/usr/bin/env nu
            use init.nu [pueue-extend now]

            if ($env.CONFIGFILE? | is-not-empty) {
                run-ferron $env.CONFIGFILE
            }

            def run-ferron [config] {
                mut cmd = ["/opt/ferron/ferron"]
                if $config != "." {
                    $cmd ++= [--config $config]
                }
                pueue-extend default 1
                pueue add --group default -l ferron -- ($cmd | str join " ")
            }
            '
            | str trim
            | str replace -rma $'^\s{12}' ''
            | save ($new | path join entrypoint ferron.nu)
        }
    }
}
