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
        let pkg = open $PKG
        | get packages
        | transpose k v
        | reduce -f [] {|i,a|
            if ($i.v.exclude_vessel? | default false) {
                $a
            } else {
                $a | append $i.k
            }
        }
        hub install $pkg -c $ctx.cache? -t /opt/vessel --bundle --with-python
    }
}
