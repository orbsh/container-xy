use ../bx *

export def --env main [context: record = {}] {
    {
        from: $'($context.image):rust'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build --no-commit --expose {|ctx|
        cargo install mistralrs-cli
    }
}
