use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
        tags: mihomo
    }
    | merge $context
    | build {|ctx|
    }
    {
        from: $'($context.image):sid'
        user: master
        workdir: /home/master
        tags: singbox
    }
    | merge $context
    | build {|ctx|
    }
}
