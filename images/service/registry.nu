use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
        tags: registry
    }
    | merge $context
    | build {|ctx|
    }
}
