use utils.nu *
use trace.nu
use hub.nu

export def install [pkgs] {
    let pkgs = $pkgs | str join ' '
    match $env.OS_RELEASE_ID {
        arch => {
            run [
                $"pacman -Sy --noconfirm ($pkgs)"
                "rm -rf /var/cache/pacman/pkg/*"
            ]
        }
        debian => {
            run [
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
            run [
                $"pacman -Sy --noconfirm ($pkgs)"
            ]
        }
        debian => {
            run [
                'apt-get update'
                $'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ($pkgs)'
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
        debian => {
            run [
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
            run ["pacman -Syu --noconfirm"]
        }
        debian => {
            run [
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

export def 'setup duckdb' [
    pkgs
    --target(-t): string = '/usr/local'
    --cache(-c): string = ''
    --archive
] {
    hub install [duckdb] -t $target -c $cache --archive=$archive
    duckdb extension $pkgs --dir ($target | path join 'share/duckdb/extensions')
}

export def 'duckdb extension' [
    pkgs
    --dir(-d): string = '/opt/duckdb/extensions'
] {
    trace o -p 'duckdb-extensions' $pkgs
    # httpfs delta ducklake iceberg postgres sqlite fts
    # conf env {
    #     DUCKDB_EXTENSION_DIRECTORY: $dir
    # }
    with-mount {
        [
            $"SET extension_directory = '($dir)';"
            'SET autoinstall_known_extensions = true;'
            'SET autoload_known_extensions = true;'
        ]
        | str join (char newline)
        | save -a root/.duckdbrc
    }

    let pkgs = $pkgs
    | each {|x| $"INSTALL ($x)" }
    | str join '; '
    run [ $"duckdb -c '($pkgs)'" ]
}
