use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
        tags: ci
    }
    | merge $context
    | build {|ctx|
        pkg install [
            buildah skopeo podman
            jq fd ripgrep
        ]
        hub install [kubectl helm]

        pkg pip install [
            furl markdown
            ansible kubernetes
            psycopg[binary] kafka-python
            pymongo github3.py
        ]
        [
            ansible.posix
            community.docker
            community.mongodb
            community.mysql
            community.postgresql
            community.general
            community.windows
            kubernetes.core
        ]
        | each { $"ansible-galaxy collection install ($in)" }
        | run $in
    }
}
