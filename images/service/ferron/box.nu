#!/usr/bin/env -S nu --stdin

export def main [] {
    let n = $in
    print "Content-Type: application/json\n"
    match $env.REQUEST_METHOD {
        POST => {
            let i = $n | upload
            # format pattern
            let q = $env.QUERY_STRING? | default '' | url split-query
            {
                event: $i
                query: $q
            }
        }
        INFO => {
            info
        }
        BODY => {
            {
                type: ($n | describe)
                body: $n
            }
        }
        _ => {
          {status: ok}
        }
    }
    | to json -r
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

def info [] {
    $env
    | transpose k v
    | where {|x|
        $x.k =~ '^(HTTP|PATH|QUERY|REMOTE|REQUEST|SCRIPT|SERVER|CONTENT|GATEWAY|DOCUMENT)_'
    }
    | reduce -f {} {|i, a|
        $a | insert $i.k $i.v
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

