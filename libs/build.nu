use lg.nu

export def main [acts --squash --skip-push] {
    let ctx = $in
    let working_container = buildah from $ctx.from
    let mountpoint = buildah mount $working_container
    buildah config --author $ctx.author $working_container

    with-env  {
        BUILDAH_WORKING_CONTAINER: $working_container
        BUILDAH_WORKING_MOUNTPOINT: $mountpoint
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
