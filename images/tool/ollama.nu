use ../../libs *

export def main [context: record = {}] {
    {
        from: 'ollama/ollama'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        pkg install [git sudo]

        setup git $ctx.author
        let xdg_config = $"/home/($ctx.user)/.config"
        setup master $ctx.user $ctx.workdir $xdg_config

        nushell setup '/usr/local' {
            user: $ctx.user
            dst: $xdg_config
            plugins: [query]
        }

        conf volume [/root/.ollama]
        copy entrypoint /entrypoint
        conf entrypoint ["/entrypoint/init.nu"]

        with-mount {
            cd entrypoint
            r#'
            #!/usr/bin/env nu
            use init.nu [pueue-extend now]

            def run-ollama [model?] {
                let act = if ($env.ENTRYPOINT_ARGS? | is-empty) {
                    'serve'
                } else {
                    $env.ENTRYPOINT_ARGS
                }
                mut cmd = ["/bin/ollama" $act]
                pueue-extend default 1
                pueue add --group default -l ferron -- ($cmd | str join " ")
            }

            run-ollama $env.MODEL_PATH?
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save ollama.nu
        }
    }
}
