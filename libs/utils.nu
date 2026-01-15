use trace.nu

export def copy [src dst] {
    trace o copy $src $dst
    buildah copy $env.BUILDAH_WORKING_CONTAINER $src $dst
}

export def run [cmd: list] {
    $cmd
    | str join ' && '
    | trace f run
    | buildah run $env.BUILDAH_WORKING_CONTAINER bash -c $in
}

export def commit [image] {
    buildah commit $env.BUILDAH_WORKING_CONTAINER $image
}

export def with-mount [act] {
    let tg = $env.BUILDAH_WORKING_MOUNTPOINT
    let old = $env.PWD
    cd $tg
    trace o -p with-mount $tg
    do $act $tg $old
}

export module conf {
    export def env [rec: record] {
        $rec
        | trace f config env
        | items {|k, v| [--env ($k)=($v)] }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def expose [vec: list] {
        $vec
        | trace f config expose
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
        | trace f config volume
        | each {|x| [--volume $x] }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def workdir [...vec] {
        $vec
        | trace f config workdir
        | each {|x| [--workingdir $x] }
        | flatten
        | buildah config ...$in $env.BUILDAH_WORKING_CONTAINER
    }

    export def entrypoint [vec: list] {
        $vec
        | trace f config entrypoint
        | to json -r
        | buildah config --entrypoint $in $env.BUILDAH_WORKING_CONTAINER
    }

    export def cmd [vec: list] {
        $vec
        | trace f config cmd
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
