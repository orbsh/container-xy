use utils.nu *

export def install [pkgs] {
    match $env.OS_RELEASE_ID {
        arch => {
            run [
                $"pacman -Sy --noconfirm ($pkgs | str join ' ')"
                "rm -rf /var/cache/pacman/pkg/*"
            ]
        }
    }
}

export def with [pkgs act] {
    let pkgs = $pkgs | str join ' '
    match $env.OS_RELEASE_ID {
        arch => {
            run [
                $"pacman -Sy --noconfirm ($pkgs)"
            ]
        }
    }

    let r = do $act

    match $env.OS_RELEASE_ID {
        arch => {
            run [
                $"pacman -Rsn --noconfirm ($pkgs)"
                "rm -rf /var/cache/pacman/pkg/*"
            ]
        }
    }
    $r
}

export def update [] {
    match $env.OS_RELEASE_ID {
        arch => {
            run ["pacman -Syu --noconfirm"]
        }
    }
}

export def 'pip install' [
    pkgs
    --index-url: string
] {
    mut cmd = [pip install --no-cache-dir --break-system-packages]
    if ($index_url | is-not-empty) {
        $cmd ++= [--index-url $index_url]
    }
    $cmd ++= $pkgs
    run [ ($cmd | str join ' ') ]
}

export def 'setup python' [pkgs] {
    install [
        python python-pip
    ]
    pip install $pkgs
}

          
export def 'bun install' [
    pkgs
] {
    mut cmd = [bun install --global --no-cache]
    $cmd ++= $pkgs
    run [ ($cmd | str join ' ') ]
}

export def 'setup js' [pkgs] {
    install [
        bun
    ]
    bun install $pkgs
}
