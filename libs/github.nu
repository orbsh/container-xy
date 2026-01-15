use lg.nu
use transformer.nu
use extract.nu
const CFG = path self ../,.toml

def get-version [repo] {
    let ver = curl --retry 3 -fsSL https://api.github.com/repos/($repo)/releases/latest | from json | get tag_name
    log -p 'get-version' { repo: $repo, version: $ver }
    $ver
}

export def install [
    tag
    --target(-t): string = '/usr/local'
] {
    let cfg = open $CFG | get github | get $tag
    let uri = {
        version: (get-version $cfg.repo | transformer run $cfg.version?)
        arch: $nu.os-info.arch
    }
    | format pattern $cfg.uri

    let wd = mktemp -t -d
    cd $wd

    let f = $uri | url parse | get path | path parse
    let f = [$f.stem $f.extension] | str join '.'
    curl --retry 3 -fsSL $uri -o $f

    let ext = $uri | split row '.' | last 2
    cat $f | extract as $ext $f

    let dst = extract unpack $cfg.unpack?

    cd ($dst | last)
    tar -cf * | tar -xf - -C $target

    for d in ($dst | append $wd | uniq) {
        rm -rf $wd
    }
}
