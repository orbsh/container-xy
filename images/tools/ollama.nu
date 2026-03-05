use ../../bx *

export def main [context: record = {}] {
    {
        from: 'ollama/ollama'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        pkg install [curl zstd git sudo]
        conf cmd [srv]

        setup git $ctx.author
        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config

        nushell setup '/usr/local' {
            user: $ctx.user
            xdg_config: $xdg_config
            plugins: [query]
        }
        with-mount {|new, old|
            cd ($new)/root
            cp ($new)/home/($ctx.user)/.config/nushell/scripts/llm/integration/ollama.nu .
        }

        conf volume [/root/.ollama]
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/libs/init.nu"]

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
                let cmd = ["/bin/ollama" ...$act]
                | str join " "

                tasks spawn {
                    tag: ollama
                    cmd: $cmd
                }
            }

            run-ollama $env.MODEL_PATH?
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save ollama.nu
        }
    }
}
