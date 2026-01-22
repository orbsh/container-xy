use ../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
        tags: ci
    }
    | merge $context
    | build {|ctx|
        hub install -c $ctx.cache? [ helm kubectl ]
    }
}
