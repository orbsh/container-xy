use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: zeroclaw }
    | build {|ctx|
        hub install -c $ctx.cache? [zeroclaw]
        with-mount {

            let tmpl = r#'
            #!/usr/bin/env nu
            use libs/tasks.nu

            tasks spawn {
                tag: zeroclaw
                cmd: 'zeroclaw gateway'
            }
            '#
            | str trim
            | str replace -rma '^ {12}' ''
            | save entrypoint/zeroclaw.nu
        }

        conf expose [7890 7891 9090]
        conf cmd ['srv']
        conf workdir /data
    }
}
