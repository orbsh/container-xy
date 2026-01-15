use lg.nu
use transformer.nu
const CFG = path self ../,.toml

def get-version [repo] {
    let ver = curl --retry 3 -fsSL https://api.github.com/repos/($repo)/releases/latest | from json | get tag_name
    log -p 'get-version' { repo: $repo, version: $ver }
    $ver
}

export def install [tag] {
    let cfg = open $CFG | get github | get $tag
    let uri = {
        version: (get-version $cfg.repo)
        arch: $nu.os-info.arch
    }
    | format pattern $cfg.uri

    curl --retry 3 -fsSL $uri
}


