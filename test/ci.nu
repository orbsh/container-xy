use ../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):ci'
        user: master
        workdir: /home/master
        tag: ci-test
    }
    | merge $context
    | build {|ctx|
        hub install --cache ~/Downloads [wasmtime]
    }
}
