#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    match ($env.REQUEST_METHOD | str downcase) {
        post | put => {
            let i = $in | upload
            let segments = ($env.PATH_INFO | path split | skip 1)
            let hooks_root = [
                $env.DOCUMENT_ROOT
                ($env.BOX_PREFIX | str trim -c '/')
                ($env.HOOKS_PATH? | default '__hooks__')
            ] | path join

            mut hook_path = ''

            let paths = [ $segments ($segments | drop 1 | append '_') ]
            | append (1..($segments | length) | each {|i| $segments | drop $i | append '__'})


            for p in $paths {
                let candidate_path = $hooks_root | path join ...$p
                if ($candidate_path | path exists) {
                    $hook_path = $candidate_path
                    break
                }
            }

            content -j

            if ($hook_path | is-not-empty) {
                let workdir = mktemp -d
                cd $workdir
                let script = [$workdir run.nu] | path join
                $"(open -r $hook_path)\n\nexport def main [] { let o = $in | from json; file_uploaded $o }" | save -f $script
                $i
                | insert location {|x| $env.DOCUMENT_ROOT | path join ($x.filename | str trim -c '/')}
                | to json -r
                | nu --stdin $script
                cd ..
                rm -rf $workdir
            } else {
                $i | to json -r
            }
        }
        _ => {
            index
        }
    }
}

def index [] {
    let file = path-to-file $env.BOX_PREFIX
    send-file $file
}

def upload [] {
    let n = $in
    let dest = path-to-file $env.BOX_PREFIX
    let parent = $dest | path parse | get parent
    if not ($parent | path exists) {
        mkdir $parent
    }
    $n | save -f $dest
    let binary = ($n | describe -d).type == 'binary'
    let size = if $binary {
        $n | bytes length
    } else {
        $n | str length
    }
    {
        event: "file_uploaded",
        host: $env.HTTP_HOST
        binary: $binary
        size: $size
        filename: $env.PATH_INFO,
        timestamp: (date now | format date "%+")
    }
}
