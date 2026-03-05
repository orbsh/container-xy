use ../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):rust'
        user: master
        workdir: /home/master
        tag: test
    }
    | merge $context
    | build {|ctx|
        conf user master
    }
}
