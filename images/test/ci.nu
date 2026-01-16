use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
        tags: ci
    }
    | merge $context
    | build {|ctx|
        github install -c $ctx.cache? [ helm istio kubectl ]
    }
}
