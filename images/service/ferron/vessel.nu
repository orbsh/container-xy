#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

const mount = 'vessel'

export def main [] {
    let n = $in
    let pkg = $env.PATH_INFO | str lowercase | path split | last
    let q = $env.QUERY_STRING? | default '' | url split-query | reduce -f {} {|i,a| $a | insert $i.key $i.value }
    let dest = $q.dest? | default $q.target? | default /usr/local
    match [($q.op? | default '') $pkg] {
        [install $pkgs] => {
            content -p
            let invalid = $pkgs | split row ',' | where {|it|
                '/opt/vessel' | path join $q.arch $"($it).tar.zst" | path exists | not $in
            }
            if ($invalid | is-not-empty) {
                cd ('/opt/vessel' | path join $q.arch)
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
                install \($i\) $'($env.HTTP_HOST)/($mount)/\($i\).tar.zst?arch=($q.arch)&op=download' ($dest)
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
        [download $pkg] => {
            let f = '/opt/vessel' | path join $q.arch $pkg
            send-file $f
        }
        [_ $args] => {
            content -p
            let q = if ($env.QUERY_STRING? | is-not-empty) { $'&($env.QUERY_STRING)' } else { '' }
            $"
            ARCH=$\(uname -m\)
            if ! command -v nu >/dev/null 2>&1; then
                echo \"nu not found. installing\"
                curl -SL --progress-bar \"($env.HTTP_HOST)/($mount)/nushell.tar.zst?arch=${ARCH}&op=download\" | zstd -d | tar -xf - -C /usr/local
            fi
            curl -SL --progress-bar \"($env.HTTP_HOST)/($mount)/($args)?arch=${ARCH}&op=install&dest=($dest)\" | $\(command -v nu\) --stdin -c 'nu -c $in'
            "
            | str trim
            | str replace -rma '^ {12}' ''
            | print $in
        }
        _ => {
            content -p
            print ({pkgs: $pkg, ...$q} | to json)
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

def install [tag url loc] {
    let file = $url | url parse | get path | path split | last
    let file = '/tmp' | path join $file
    curl -SL --progress-bar $url -o $file
    let fs = tar-fs $file
    info --lv 1 $'extract'
    cat $file | zstd -d | tar -xvf - --no-overwrite-dir -C $loc ...($fs | where $it not-in [setup.nu])
    if 'setup.nu' in $fs {
        let f = '/tmp' | path join ($tag)_setup.nu
        info --lv 1 $'run ($f)'
        cat $file | zstd -d | tar -Oxf - setup.nu | save -f $f
        cd
        nu $f $'{target: ($loc)}'
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
