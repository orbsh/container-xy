#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    match ($env.REQUEST_METHOD | str downcase) {
        post | put => {
            let i = $in | upload
            let hook = [
                $env.DOCUMENT_ROOT
                ($env.HOOKS_PATH? | default '__hooks__')
                ...($env.PATH_INFO | path split | skip 1)
            ]
            | path join

            content -j

            if ($hook | path exists) {
                let workdir = mktemp -d
                cd $workdir
                let script = [$workdir run.nu] | path join
                $"(open -r $hook)\n\nexport def main [] { let o = $in | from json; file_uploaded $o }" | save -f $script
                $i
                | insert location {|x| $env.DOCUMENT_ROOT | path join ($x.filename | str substring 1..)}
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
    let file = path-to-file
    send-file $file
}

def upload [] {
    let n = $in
    let dest = path-to-file
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
