use trace.nu
use b.nu

export def enter --env [from] {
    trace inc-level
    let working_container = buildah from $from
    let mountpoint = buildah mount $working_container

    {
        BUILDAH_WORKING_CONTAINER: $working_container
        BUILDAH_WORKING_MOUNTPOINT: $mountpoint
    }
    | trace f inject environment
    | load-env
}

enter ghcr.io/fj0r/xy:z
