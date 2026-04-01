use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        conf expose [8080]
        conf env {
            HOST: '0.0.0.0'
            PORT: '8080'
        }
        pkg with [ base-devel ] {
            pkg pip install [
                "'transformers<4.49'" "'optimum<2.0'" "infinity-emb[all]"
            ]
        }
        let model = 'codefuse-ai/F2LLM-v2-0.6B'
        run [
            $'infinity_emb v2 --model-id ($model) --preload-only'
        ]
        with-mount {
            cd entrypoint
            r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            let cmd = [
                infinity_emb v2 --model-id ($model) --port 8080 --device cpu
            ]
            | str join " "

            tasks spawn {
                tag: f2llm
                msg: "Starting f2llm."
                cmd: $cmd
            }
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save marimo.nu
        }
        conf cmd ['srv']
        conf user master
    }
}
