use lg.nu
use utils.nu *

export def enter --env [from] {
    let working_container = buildah from $from
    let mountpoint = buildah mount $working_container

    {
        BUILDAH_WORKING_CONTAINER: $working_container
        BUILDAH_WORKING_MOUNTPOINT: $mountpoint
    }
    | lg f inject environment
    | load-env
}

enter ghcr.io/fj0r/xy:z
