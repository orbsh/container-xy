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
