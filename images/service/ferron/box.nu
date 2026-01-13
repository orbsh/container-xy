#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    match ($env.REQUEST_METHOD | str downcase) {
        post => {
            let i = $in | upload
            content -j
            $i | to json -r
        }
        _ => {
            index
        }
    }
}

def index [] {
    let file = $env.PATH_INFO | path split | where { $in != '/' } | path join
    let file = $env.DOCUMENT_ROOT | path join $file
    match ($file | path type) {
        file => {
            content
            open -r $file
        }
        dir => {
            cd $file
            content -j
            ls | to json -r
        }
        _ => {
            status 404
        }
    }
}

def upload [] {
    let n = $in
    let file = $env.PATH_INFO | path split | where { $in != '/' } | path join
    let dest = $env.DOCUMENT_ROOT | path join $file
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
        filename: ('/' | path join $file),
        timestamp: (date now | format date "%+")
    }
}


def webhook [url payload] {
    try {
        let response = (http post -t application/json $url $payload)
        { status: "success", webhook_response: $response }
    } catch {
        { status: "error", message: "Webhook failed" }
    }
}

