#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    let path = $env.PATH_INFO | str downcase | path split | slice 1..
    match $path {
        [vessel install $arch $pkgs] => {
            content -p
            let invalid = $pkgs | split row ',' | where {|it|
                '/opt/vessel' | path join $arch $"($it).tar.zst" | path exists | not $in
            }
            if ($invalid | is-not-empty) {
                cd ('/opt/vessel' | path join $arch)
                let pkgs = do -i { ls *.tar.zst }
                | default []
                | get name
                | each { $in | split row '.' | first }

                {
                    invalid: $invalid
                    allowed: $pkgs
                }
                | $"($in) | to json | print $in"
                | print $in
                return
            }
            let r = $"
            for i in ($pkgs | split row ',') {
                info $'install \($i\)'
                install $'($env.HTTP_HOST)/vessel/download/($arch)/\($i\).tar.zst' /usr/local
            }
            "
            | str trim
            | str replace -rma '^ {12}' ''
            [
                (view source info)
                (view source tar-fs)
                (view source install)
                $r
            ]
            | str join (char newline)
            | print $in
        }
        [vessel download $arch $pkg] => {
            let f = '/opt/vessel' | path join $arch $pkg
            send-file $f
        }
        [vessel $args] => {
            content -p
            $"
            ARCH=$\(uname -m\)
            if ! command -v nu >/dev/null 2>&1; then
                echo \"nu not found. installing\"
                curl -SL --progress-bar ($env.HTTP_HOST)/vessel/download/${ARCH}/nushell.tar.zst | zstd -d | tar -xf - -C /usr/local
            fi
            curl -SL --progress-bar ($env.HTTP_HOST)/vessel/install/${ARCH}/($args) | /usr/local/bin/nu --stdin -c 'nu -c $in'
            "
            | str trim
            | str replace -rma '^ {12}' ''
            | print $in
        }
        _ => {
            content -p
            print $path
        }
    }
}

def tar-fs [f] {
    tar -tf $f
    | lines
    | reduce -f {} {|i,a|
        $a | upsert ($i | path split | first) true
    }
    | columns
}

def install [url loc] {
    let file = $url | path split | last
    let file = '/tmp' | path join $file
    curl -SL --progress-bar $url -o $file
    let fs = tar-fs $file
    info --lv 1 $'extract'
    cat $file | zstd -d | tar -xvf - -C $loc ...($fs | where $it not-in [config setup.nu])
    if 'config' in $fs {
        info --lv 1 $'config'
        cat $file
        | zstd -d
        | tar -xf - --strip-component=1 config -C (
            $env.HOME | path join '.config'
        )
    }
    if 'setup.nu' in $fs {
        info --lv 1 $'setup'
        cd
        cat $file
        | zstd -d
        | tar -Oxf - setup.nu
        | nu -c $in
    }
}

def info [msg --lv:int --total:int] {
    let time = date now | format date '%FT%T.%3f'
    # HACK: view source
    let lv = if ($lv | is-empty) { 0 } else { $lv }
    let total = if ($total | is-empty) { 6 } else { $total }
    let lv = '' | fill -c '*' -w ($total - $lv) | fill -c ' ' -w $total -a right
    print $"(ansi grey)($lv)│($time)│($msg)(ansi reset)"
}
