use trace.nu
use transformer.nu
use extract.nu
use utils.nu *
const CFG = path self ../github.yaml

export def get-version [repo] {
    let ver = if ($repo | str starts-with 'http') {
        curl --retry 3 -fsSL $repo
    } else {
        let url = $"https://api.github.com/repos/($repo)/releases/latest"
        curl --retry 3 -fsSL $url | from json | get tag_name
    }
    trace o -p 'version' { repo: $repo, version: $ver }
    $ver
}

export def install [
    ...tags
    --target(-t): string = '/usr/local'
    --unpack(-u): closure
    --cache(-c): string = ''
] {
    for t in $tags {
        trace o -p 'github-install' $t
        install-inner $t -t $target -u $unpack -c $cache
    }
}

def install-inner [
    tag
    --target(-t): string
    --unpack(-u): closure
    --cache(-c): string
] {
    let cfg = open $CFG | get packages | get $tag
    let ev = {
        version: (get-version $cfg.repo | transformer run $cfg.version?)
        arch: $nu.os-info.arch
    }
    let uris = if ($cfg.uri | describe -d).type == list {
        $cfg.uri
    } else {
        [$cfg.uri]
    }
    | each {|x| $ev | format pattern $x }

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
    let dst = extract unpack $upk

    cd ($dst | last)
    trace o -p 'files-ready' $env.PWD
    tree
    with-mount {|new, old|
        let t = $new | path join (relative-path $target)
        let d = $t | path parse | get parent
            trace o -p 'target' {t : $t, target: $target, d: $d}
        if not ($d | path exists) {
            trace o -p 'create-dir' $d
            mkdir $d
        }
        cd $old
        cp -r -v * $t
    }

    cd $origin
    for d in ($dst | append $wd | uniq) {
        trace o -p 'clean temp dir' $d
        rm -rf $d
    }
}
