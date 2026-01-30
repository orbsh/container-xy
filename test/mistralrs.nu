use ../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):rust'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build --no-commit --export {|ctx|
        cargo install mistralrs-cli
    }
}
