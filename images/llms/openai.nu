use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):mistralrs'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        run []
    }
}
