use trace.nu
use transformer.nu
use extract.nu
use b.nu
const CFG = path self ../hub.yaml

export def get-version [cfg] {
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

export def install [
    tags
    --user: string
    --author(-A): string
    --target(-t): string = '/usr/local'
    --unpack(-u): closure
    --cache(-c): string = ''
    --archive
] {
    for t in $tags {
        trace o -p 'hub-install' $t
        install-inner $t -t $target -u $unpack -c $cache --archive=$archive --user $user -A $author
    }
}


def install-inner [
    tag
    --user: string
    --author(-A): string
    --target(-t): string
    --unpack(-u): closure
    --cache(-c): string
    --archive
] {
    let cfg = open $CFG | get packages | get $tag
    let ev = {
        version: (get-version $cfg | transformer run $cfg.version?)
        arch: $nu.os-info.arch
        arch2: (arch2 $nu.os-info.arch)
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


    let upk = if ($unpack | is-empty) { {|x| $x} } else { $unpack }
    let upk = do $upk (
        $cfg.unpack? | default [] | each {|x| $ev | format pattern $x}
    )
    let dst = extract unpack $upk | prepend $wd

    trace o -p 'temp-dirs' $dst
    cd ($dst | last)
    trace o -p 'files-ready' $env.PWD
    tree
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

        const self = path self .
        let envs = {
            cfg: $cfg
            context: $origin
            mount: $new
            target: $target
            workdir: $env.PWD
            user: $user
            author: $author
        }
        | to nuon

        if ($cfg.hooks?.prepare? | is-not-empty) {
            with-env {HUBHOOK: $envs} {
                let exe = mktemp -p $self
                $cfg.hooks.prepare | save -f $exe
                print '<<<<<< prepare'
                nu $exe
                print '>>>>>> prepare'
                rm -f $exe
            }
        }

        if $archive {
            tar -cvf - *
            | zstd -18 -T0
            | save -f ($t | path join $'($tag).tar.zst')
        } else {
            cp -r -v * $t
        }

        if ($cfg.hooks?.after? | is-not-empty) {
            with-env {HUBHOOK: $envs} {
                let exe = mktemp -p $self
                $cfg.hooks.after | save -f $exe
                print '<<<<<< after'
                nu $exe
                print '>>>>>> after'
                rm -f $exe
            }
        }
    }

    cd $origin
    for d in ($dst | uniq) {
        trace o -p 'clean temp dir' $d
        rm -rf $d
    }
}
