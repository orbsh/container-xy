use trace.nu

export def main --env [
    acts
    --export
    --no-commit
    --squash
] {
    let ctx = $in
    let working_container = buildah from $ctx.from
    let mountpoint = buildah mount $working_container
    buildah config --author $ctx.author $working_container

    let os_id = open -r ($mountpoint | path join etc/os-release)
    | lines
    | reduce -f {} {|i, a|
        let i = $i | split row '='
        $a | insert ($i.0 | str downcase) $i.1
    }
    let os_id = $os_id.id_like? | default $os_id.id

    let envs = {
        OS_RELEASE_ID: $os_id
        BUILDAH_WORKING_CONTAINER: $working_container
        BUILDAH_WORKING_MOUNTPOINT: $mountpoint
        # TODO: ssh support (libs/utils.nu)
        SSH_WORKING_HOST: ''
        TRACE_LEVEL: 0
    }

    with-env $envs {
        do $acts $ctx
    }

    if $export {
        $envs | trace f inject-environment | load-env
    }

    if $no_commit or $export {
        return $envs
    }

    buildah unmount $working_container

    let image = ($ctx.image):($ctx.tags? | default 'latest')
    trace o commit $image
    if $squash {
        buildah commit --squash $working_container $image
    } else {
        buildah commit $working_container $image
    }

    if not ($ctx.skip_push? | default false) {
        trace o push $image
        buildah push --creds ($ctx.author):($ctx.password) $image
    }
}
