use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):py'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        hub install [lightpanda]
        conf expose [9222]

        pkg setup python [
            playwright
        ]

        with-mount {
            cd entrypoint
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            let lv = $env.LOG_LEVEL? | default info | str downcase
            let proxy = if ($env.HTTP_PROXY? | is-not-empty) {
                [--http_proxy $env.HTTP_PROXY]
            } else {
                []
            }
            let cmd = [
                /usr/local/bin/lightpanda
                serve
                --host 0.0.0.0
                --port 9222
                ...$proxy
                --log_level info
            ]
            | str join " "

            tasks spawn {
                tag: ollama
                cmd: $cmd
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save lightpanda.nu
        }
    }
}
