export def content [
  --json(-j)
  --plain(-p)
  --html(-h)
] {
    if $json {
        print "Content-Type: application/json; charset=utf-8\n"
    } else if $plain {
        print "Content-Type: text/plain\n"
    } else if $html {
        print "Content-Type: text/html; charset=utf-8\n"
    } else {
        print "Content-Type: application/octet-stream\n"
    }
}

export def status [code] {
    match $code {
        401 => {
            print "Status: 401 Unauthorized\n"
        }
        403 => {
            print "Status: 403 Forbidden\n"
        }
        404 => {
            print "Status: 404 Not Found\n"
        }
    }
}

export def is-binary-file []: binary -> bool {
    $in | first 512 | bytes index-of 0x[00] | $in >= 0
}

export def query [] {
    $env.QUERY_STRING? | default '' | url split-query
}

export def path-to-file [] {
  $env.DOCUMENT_ROOT | path join ($env.PATH_INFO | str substring 1..)
}

export def send-file [file] {
    match ($file | path type) {
        file => {
            let is_bin = open -r $file | into binary | is-binary-file
            if $is_bin {
                content
                cat $file
            } else {
                content -p
                open -r $file
            }
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

export def envs [] {
    $env
    | reject PROMPT_COMMAND ENV_CONVERSIONS PROMPT_COMMAND PROMPT_COMMAND_RIGHT config
}

export def json [...acts] {
    print "Content-Type: application/json\n"
    for a in $acts {
        let x = do $a
        if ($x | is-not-empty) {
            return ($x | to json -r)
        }
    }
}

export def route [
    pattern
    act
    --method(-m): string
] {
    if ($method | is-not-empty) {
        if ($env.REQUEST_METHOD | str downcase) != ($method | str downcase) {
            return
        }
    }
    let d = $env.PATH_INFO | parse -r $pattern
    if ($d | is-not-empty) {
        do $act ($d | first)
    }
}
