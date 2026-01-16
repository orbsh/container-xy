use trace.nu
use transformer.nu
use extract.nu
use utils.nu *
const CFG = path self ../,.toml

export def get-version [repo] {
    let ver = curl --retry 3 -fsSL https://api.github.com/repos/($repo)/releases/latest | from json | get tag_name
    trace o -p 'version' { repo: $repo, version: $ver }
    $ver
}

export def install [
    ...tags
    --target(-t): string = '/usr/local'
    --unpack(-u): closure
] {
    for t in $tags {
        trace o -p 'github-install' $t
        install-inner $t -t $target -u $unpack
    }
}

def install-inner [
    tag
    --target(-t): string = '/usr/local'
    --unpack(-u): closure
] {
    let cfg = open $CFG | get github | get $tag
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

    let wd = mktemp -t -d --suffix .buildah
    cd $wd

    for uri in $uris {
        let f = $uri | url parse | get path | path parse
        let f = [$f.stem $f.extension] | str join '.'
        let cache = if ($cfg.cache? | is-not-empty) {
            ($cfg.cache)/($f) | path expand
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
        cd $old
        cp -r -v * $t
    }

    for d in ($dst | append $wd | uniq) {
        rm -rf $wd
    }
}
