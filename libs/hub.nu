use trace.nu
use transformer.nu
use extract.nu
use b.nu
const CFG = path self ../hub.yaml

export def get-version [cfg] {
    trace inc-level
    let ver = if ($cfg.repo | str starts-with 'http') {
        curl --retry 3 -fsSL $cfg.repo
    } else if ($cfg.with_prerelease? | default false) {
        let url = $"https://api.github.com/repos/($cfg.repo)/releases"
        curl --retry 3 -fsSL $url | from json | first | get tag_name
    } else {
        let url = $"https://api.github.com/repos/($cfg.repo)/releases/latest"
        curl --retry 3 -fsSL $url | from json | get tag_name
    }
    trace o -p 'version' { repo: $cfg.repo, version: $ver }
    $ver
}

def arch2 [a] {
    match $a {
        'x86_64' => 'amd64',
        'aarch64' => 'arm64',
        'i386' | 'i686' => '396',
        'armv7' | 'armhf' => 'arm'
        _ => $a
    }
}

def arch3 [a] {
    match $a {
        'x86_64' => 'x64',
        _ => $a
    }
}

export def install [
    tags
    --user: string
    --author(-A): string
    --target(-t): string = '/usr/local'
    --option(-o): closure
    --cache(-c): string = ''
    --arch: string
    --bundle
    --with-python
] {
    trace inc-level
    for t in $tags {
        trace o -p 'hub-install' $t
        (
            install-inner
            $t
            -t $target
            -o $option
            -c $cache
            --bundle=$bundle
            --arch $arch
            --user $user
            -A $author
            --with-python=$with_python
        )
    }
}


def install-inner [
    tag
    --user: string
    --author(-A): string
    --target(-t): string
    --option(-o): closure
    --cache(-c): string
    --arch: string
    --bundle
    --with-python
] {
    trace inc-level
    let cfg = open $CFG | get packages | get $tag
    let arch = if ($arch | is-empty) { $nu.os-info.arch } else { $arch }

    let python_version = if $with_python {
        http get https://www.python.org/downloads/source/
        | grep -oP 'Latest Python 3 Release - Python \K[0-9.]+'
    } else {
        ''
    }

    let ev = {
        version: (get-version $cfg | transformer run $cfg.version?)
        arch: $arch
        arch2: (arch2 $arch)
        arch3: (arch3 $arch)
        python_version: $python_version
    }

    let uris = if ($cfg.uri | describe -d).type == list {
        $cfg.uri
    } else {
        [$cfg.uri]
    }
    | each {|x|
        let u = $ev | format pattern $x
        if ($u | str starts-with 'http') {
            $u
        } else {
            $'https://github.com/($cfg.repo)/releases' | path join $u
        }
    }

    let origin = pwd

    let wd = mktemp -t -d --suffix .buildah
    cd $wd

    for uri in $uris {
        let f = $uri | url parse | get path | path parse
        let f = [$f.stem $f.extension]
        | where { $in | is-not-empty }
        | str join '.'

        let cache = if ($cache | is-not-empty) {
            ($cache)/($f) | path expand
        }
        if ($cache | is-empty) {
            curl --retry 3 -fsSL $uri -o $f
        } else {
            if not ($cache | path exists) {
                curl --retry 3 -fsSL $uri -o $cache
            }
            cp $cache $f
        }

        let ext = $uri | split row '.' | last 2
        cat $f | extract as $ext $f
    }


    let upk = $cfg.unpack? | default [] | each {|x| $ev | format pattern $x}
    let dst = extract unpack $upk | prepend $wd

    trace o -p 'temp-dirs' $dst
    cd ($dst | last)
    trace o -p 'files-ready' $env.PWD
    b with-mount {|new, old|
        let target = b relative-path $target
        let t = $new | path join $target
        mkdir $t
        let d = $t | path parse | get parent
        trace o -p 'target' {t : $t, target: $target, d: $d}
        if not ($d | path exists) {
            trace o -p 'create-dir' $d
            mkdir $d
        }
        cd $old

        let opt = $cfg.options? | default {}
        let opt = if ($option | is-empty) { $opt } else { do $option $opt }
        let envs = {
            options: $opt
            context: $origin
            mount: $new
            target: $target
            workdir: $env.PWD
            user: $user
            author: $author
        }

        tree
        $cfg.hooks?.prepare? | run-script HUBHOOK $envs [ trace.nu ]

        if $bundle {
            mkdir ($t | path join $arch)
            if ($cfg.hooks?.post? | is-not-empty) {
                $cfg.hooks.post | gen-script HUBHOOK ($envs | merge {
                    context: ''
                    mount: '/'
                    target: 'usr/local'
                    workdir: ''
                }) [ trace.nu ]
                | save -f setup.nu
            }
            tar -cvf - *
            | zstd -18 -T0
            | save -f ($t | path join $arch $'($tag).tar.zst')
        } else {
            cp -r -v * $t
            $cfg.hooks?.post? | run-script HUBHOOK $envs [ trace.nu ]
        }

    }

    cd $origin
    for d in ($dst | uniq) {
        trace o -p 'clean temp dir' $d
        rm -rf $d
    }
}

export def run-script [
    key: string
    envs: record
    mods: list<string>
]: any -> nothing {
    let input = $in
    if ($input | is-empty) { return }

    trace inc-level
    let ctx = mktemp -d
    trace o -p run-script $ctx

    const self = path self .
    mut $r = []
    for m in $mods {
        let n = $m | path parse | get stem
        let m = open -r ($self | path join $m)
        | str replace -rma '^' '    '
        | $"module ($n) {\n($in)\n}\nuse ($n)"
        $r ++= [$m]
    }
    let m = "
    module b {
        use trace
        export def run [cmd: list] {
            trace inc-level
            $cmd
            | str join ' && '
            | trace f run
            | buildah run $env.BUILDAH_WORKING_CONTAINER bash -c $in
        }
    }
    use b
    "
    | str trim
    | str replace -rma '^ {4}' ''
    $r ++= [$m]

    $r ++= [$input]

    let main = $ctx | path join main.nu
    $r | str join "\n\n" | save -f $main
    with-env { $key: ($envs | to nuon) } {
        nu $main
    }
    rm -rf $ctx
}

export def gen-script [
    key: string
    envs: record
    mods: list<string>
]: any -> string {
    let input = $in
    if ($input | is-empty) { return }

    mut ctx = []
    trace o -p run-script

    const self = path self .
    for m in $mods {
        let n = $m | path parse | get stem
        let m = open -r ($self | path join $m)
        | str replace -rma '^' '    '
        | $"module ($n) {\n($in)\n}\nuse ($n)"
        $ctx ++= [$m]
    }

    let m = $"
    module b {
        export def run [cmd: list] {
            $cmd
            | str join ' && '
            | bash -c $in
        }
    }
    use b
    "
    | str trim
    | str replace -rma '^ {4}' ''
    $ctx ++= [$m]

    let m = $input
    | str replace -rma '^' '    '
    | $"def run [] {\n($in)\n}"
    $ctx ++= [$m]

    let m = $"
    with-env { ($key): r#'($envs | to nuon)'# } {
        run
    }
    "
    | str replace -rma  '^ {4}' ''
    $ctx ++= [$m]

    $ctx | str join "\n\n"
}
