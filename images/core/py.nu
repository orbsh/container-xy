use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):deb'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        pkg setup py --stack [
            web dev io cli utils logging data codec
        ] [
            agno openai
        ]
    }
}
