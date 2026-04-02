use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: playwright }
    | build {|ctx|
        pkg pip install [playwright]
        run ['playwright install chromium']
    }
}
