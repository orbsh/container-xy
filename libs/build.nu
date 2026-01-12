use lg.nu

export def main [acts --squash --skip-push] {
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

    with-env  {
        OS_RELEASE_ID: $os_id
        BUILDAH_WORKING_CONTAINER: $working_container
        BUILDAH_WORKING_MOUNTPOINT: $mountpoint
        # TODO: ssh support (libs/utils.nu)
        SSH_WORKING_HOST: ''
    } {
        do $acts $ctx
    }


    let image = ($ctx.image):($ctx.tags? | default 'latest')
    lg o commit $image
    if $squash {
        buildah commit --squash $working_container $image
    } else {
        buildah commit $working_container $image
    }

    if not $skip_push {
        lg o push $image
        buildah push --creds ($ctx.author):($ctx.password) $image
    }
}
