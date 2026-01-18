use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):ferron'
        user: master
        workdir: /home/master
        tags: vessel
    }
    | merge $context
    | build {|ctx|
        const PKG = path self ../../hub.yaml
        let pkg = open $PKG | get packages | columns
        hub install $pkg -c $ctx.cache? -t /opt/vessel --archive
    }
}
