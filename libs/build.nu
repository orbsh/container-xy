use trace.nu

export def --env main [
    acts
    --expose
    --no-commit
    --squash
]: record -> any {
    let ctx = $in
    trace o -p build $ctx

    let working_container = buildah from $ctx.from
    let mountpoint = buildah mount $working_container
    if ($ctx.author? | is-not-empty) {
        buildah config --author $ctx.author $working_container
    }

    let os_id = $mountpoint | path join etc/os-release | os-id

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

    if $expose {
        $envs | trace f inject-environment | load-env
    }

    if $no_commit or $expose {
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

export def os-id []: path -> string {
    let file = $in
    # ImageVolume
    if not ($file | path exists) {
        return ''
    }
    let os_id = open -r $file
    | lines
    | reduce -f {} {|i, a|
        let i = $i | split row '='
        $a | insert ($i.0 | str downcase) $i.1
    }
    $os_id.id_like? | default $os_id.id
}
