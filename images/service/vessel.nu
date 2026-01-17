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
        hub install [
            nushell
            pueue
            websocat
            kubectl
            helm
            surrealdb
        ] -c $ctx.cache? -t /opt/vessel --archive
    }
}
