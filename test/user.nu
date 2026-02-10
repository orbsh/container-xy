use ../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):rust'
        user: master
        workdir: /home/master
        tags: test
    }
    | merge $context
    | build {|ctx|
        conf user master
    }
}
