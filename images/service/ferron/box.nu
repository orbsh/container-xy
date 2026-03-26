#!/usr/bin/env -S nu --stdin

const utils = path self utils.nu
use $utils *

export def main [] {
    match ($env.REQUEST_METHOD | str downcase) {
        post | put => {
            let i = $in | upload
            if ($env.WEBHOOK_UPLOAD? | is-not-empty) {
                webhook $env.WEBHOOK_URI $i
            }
            content -j
            $i | to json -r
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


def webhook [url payload] {
    try {
        let response = (http post -t application/json $url $payload)
        { status: "success", webhook_response: $response }
    } catch {
        { status: "error", message: "Webhook failed" }
    }
}
