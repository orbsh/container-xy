use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):ubuntu'
        user: master
        workdir: /home/master
        tags: wireguard
    }
    | merge $context
    | build {|ctx|
    }
}
