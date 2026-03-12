use b.nu
use hub.nu
use rust.nu

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

    if 'rustup' in $pkgs {
        rust up root stable
    }

    let r = do $act

    if 'rustup' in $pkgs {
        b run [
            'rustup toolchain uninstall $(rustup toolchain list)'
            'rm -rf ~/.rustup/toolchains/*'
            'rm -rf ~/.rustup/downloads/*'
            'rm -rf ~/.cargo/registry/*'
            'rm -rf ~/.cargo/git/*'
        ]
    }

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

export def refresh [] {
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
    let pip = match $env.OS_RELEASE_ID {
        debian => "pip3"
        _ => "pip",
    }
    mut cmd = [$pip install --no-cache-dir --break-system-packages]
    if ($index_url | is-not-empty) {
        $cmd ++= [--index-url $index_url]
    }
    $cmd ++= $pkgs

    b run [ ($cmd | str join ' ') ]
}

export def 'setup python' [pkgs] {
    let bin = match $env.OS_RELEASE_ID {
        debian => [ python3 python3-pip ],
        _ => [ python python-pip ],
    }
    b conf env {
        PYTHONUNBUFFERED: x
    }
    install $bin
    pip install $pkgs
}


export def 'bun install' [
    pkgs
] {
    mut cmd = [bun install --global --no-cache]
    $cmd ++= $pkgs
    b run [ ($cmd | str join ' ') ]
}

export def 'npm install' [
    pkgs
] {
    mut cmd = [npm install --global -no-cache]
    $cmd ++= $pkgs
    b run [ ($cmd | str join ' ') ]
}

export def 'setup js' [
    pkgs
    --runtime: string = 'bun'
] {
    match $runtime {
        node => {
            let bin = match $env.OS_RELEASE_ID {
                debian => [ nodejs npm ],
                _ => [ nodejs npm ],
            }
            install $bin
            npm install $pkgs
        }
        bun => {
            hub install [bun]
            bun install $pkgs
        }
    }
}
