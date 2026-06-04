use ../../bx *

export def main [context: record = {}] {
    {
        from: $'($context.image):ferron'
        user: master
        workdir: /srv
        tag: box
    }
    | merge $context
    | build {|ctx|
        pkg install [
            buildah skopeo podman
            jq ripgrep
        ]
        hub install [kubectl helm]

        with-mount {|new, old|
            let tg = $new | path join root/.config/nushell/scripts
            mkdir $tg
            for f in [bx version.yaml] {
                cp -r ($old | path join $f) $tg
            }
        }
    }
}
