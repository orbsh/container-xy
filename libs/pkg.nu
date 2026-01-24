use b.nu

export def install [pkgs] {
    let pkgs = $pkgs | str join ' '
    match $env.OS_RELEASE_ID {
        arch => {
            b run [
                $"pacman -Sy --noconfirm ($pkgs)"
                "rm -rf /var/cache/pacman/pkg/*"
            ]
        }
        debian => {
            b run [
                'apt-get update'
                $'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ($pkgs)'
                'apt-get autoremove -y'
                'apt-get clean -y'
                'rm -rf /var/lib/apt/lists/*'
            ]
        }
    }
}

export def with [pkgs act] {
    let pkgs = $pkgs | str join ' '
    match $env.OS_RELEASE_ID {
        arch => {
            b run [
                $"pacman -Sy --noconfirm ($pkgs)"
            ]
        }
        debian => {
            b run [
                'apt-get update'
                $'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ($pkgs)'
            ]
        }
    }

    let r = do $act

    match $env.OS_RELEASE_ID {
        arch => {
            b run [
                $"pacman -Rsn --noconfirm ($pkgs)"
                "rm -rf /var/cache/pacman/pkg/*"
            ]
        }
        debian => {
            b run [
                $'apt-get purge -y --auto-remove ($pkgs)'
                'apt-get clean -y'
                'rm -rf /var/lib/apt/lists/*'
            ]
        }
    }
    $r
}

export def update [] {
    match $env.OS_RELEASE_ID {
        arch => {
            b run ["pacman -Syu --noconfirm"]
        }
        debian => {
            b run [
                'apt-get update'
                'apt-get upgrade -y'
            ]
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
    b run [ ($cmd | str join ' ') ]
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
    b run [ ($cmd | str join ' ') ]
}

export def 'setup js' [pkgs] {
    install [
        bun
    ]
    bun install $pkgs
}
