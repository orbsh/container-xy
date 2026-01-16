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
        ]
        github install kubectl helm istio

        pkg pip install [
            ansible kubernetes
            'psycopg[binary]'
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
