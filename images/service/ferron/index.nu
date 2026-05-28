#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    content -j
    {
        handler: 'index.nu'
        path_info: $env.PATH_INFO
    }
    | to json -r
}
