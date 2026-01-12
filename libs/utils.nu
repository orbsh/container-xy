use lg.nu

export def copy [src dst] {
    lg o copy $src $dst
    buildah copy $env.BUILDAH_WORKING_CONTAINER $src $dst
}

export def run [cmd: list] {
    $cmd
    | str join ' && '
    | lg f run
    | buildah run $env.BUILDAH_WORKING_CONTAINER bash -c $in
}

export def commit [image] {
    buildah commit $env.BUILDAH_WORKING_CONTAINER $image
}

export def with-mount [act] {
    let tg = $env.BUILDAH_WORKING_MOUNTPOINT
    let old = $env.PWD
    cd $tg
    lg o -p with-mount $tg
    do $act $tg $old
}

export module conf {
    export def env [rec: record] {
        $rec
        | lg f config env
        | items {|k, v| [--env ($k)=($v)] }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def expose [vec: list] {
        $vec
        | lg f config expose
        | each {|x|
            let x = $x | into string
            if ($x | str starts-with u) {
                [--port ($x | str substring 1..)/udp]
            } else {
                [--port ($x)/tcp]
            }
        }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def volume [vec: list] {
        $vec
        | lg f config volume
        | each {|x| [--volume $x] }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def workdir [...vec] {
        $vec
        | lg f config workdir
        | each {|x| [--workingdir $x] }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def entrypoint [vec: list] {
        $vec
        | lg f config entrypoint
        | to json -r
        | buildah config --entrypoint $in $env.BUILDAH_WORKING_CONTAINER
    }

    export def cmd [vec: list] {
        $vec
        | lg f config cmd
        | to json -r
        | buildah config --cmd $in $env.BUILDAH_WORKING_CONTAINER
    }

    export def user [user] {
        buildah config --user $user $env.BUILDAH_WORKING_CONTAINER
    }
}

export def relative-path [path] {
    $path | path split | where $it != '/' | path join
}
