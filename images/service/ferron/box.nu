#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    let n = $in
    json {
        route '/' -m post {
            let i = $n | upload
            $i
        }
    } {
        route '/' {
            info
        }
    }
}

def upload [] {
    let root = 'ftp'
    let file = $env.PATH_INFO | path split | where { $in != '/' } | path join
    let dest = $env.DOCUMENT_ROOT | path join $root $file
    let parent = $dest | path parse | get parent
    if not ($parent | path exists) {
        mkdir $parent
    }
    $in | save -f $dest
    {
        event: "file_uploaded",
        host: $env.HTTP_HOST
        filename: ('/' | path join $root $file),
        size: ($in | bytes length),
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

