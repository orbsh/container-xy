use ../libs *

export def main [context: record = {}] {
    {
        from: 'ghcr.io/fj0r/xy:ollama'
        author: unnamed
        timezone: Asia/Shanghai
        user: master
        workdir: /home/master
        image: test
        tag: ollama
    }
    | merge $context
    | build {|ctx|
        hub install [pueue]
        conf cmd [srv]
        with-mount {
            cd entrypoint
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            def run-ollama [model?] {
                let act = if $env.ENTRYPOINT_ARGS?.0? == 'srv' {
                    ['serve']
                } else {
                    $env.ENTRYPOINT_ARGS
                }
                let cmd = ["/bin/ollama" ...$act] | str join " "
                tasks spawn {
                    tag: ollama
                    cmd: $cmd
                }
            }

            run-ollama $env.MODEL_PATH?
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save -f ollama.nu
        }
    }
}
