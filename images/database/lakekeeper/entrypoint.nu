#!/usr/bin/env nu
use libs/tasks.nu

mut args = $env.ENTRYPOINT_ARGS? | default []
if $args.0? == 'srv' { $args = $args | skip 1 } else { exit 0 }

# Migration (idempotent, runs every start)
print "Running Lakekeeper migration..."
run-external /usr/local/bin/lakekeeper "migrate"

# Start serve (queued via task system, kept alive by tasks wait in init.nu)
tasks spawn {
    tag: lakekeeper
    msg: 'Starting Lakekeeper.'
    cmd: [
        /usr/local/bin/lakekeeper
        serve
        ...$args
    ]
}

# Bootstrap (first run only, waits for serve to be ready)
let flag = "/var/lib/lakekeeper/.bootstrap_done"
if not ($flag | path exists) {
    let port = 8181

    # Wait for port readiness (serve is queued, listener will dispatch shortly)
    mut ready = false
    for attempt in 1..30 {
        let r = (
            http get --allow-errors
            $"http://localhost:($port)/management/v1/info"
        )
        let code = $r.status_code? | default 0
        if $code in [200 401 403 404] {
            $ready = true
            break
        }
        print $"Waiting for port ($port)... (attempt ($attempt)/30)"
        sleep 2sec
    }
    if not $ready {
        print $"ERROR: Port ($port) not ready after 60s"
        exit 1
    }
    print $"Port ($port) ready."

    # Bootstrap
    print "Bootstrapping Lakekeeper..."
    mut ok = false
    for attempt in 1..5 {
        let r = do -i {(
            http post --allow-errors -t application/json
            $"http://localhost:($port)/management/v1/bootstrap"
            {"accept-terms-of-use": true}
        )}
        let code = $r.status_code? | default 0
        if $code in [200 201 400 409] {
            print $"Bootstrapped (HTTP ($code))"
            $ok = true
            break
        }
        print $"Bootstrap attempt ($attempt) failed (HTTP ($code | into string))"
        sleep (1sec * $attempt)
    }
    if not $ok { exit 1 }

    # Create warehouse if S3 credentials provided
    let ak = $env.LAKEKEEPER__S3_ACCESS_KEY? | default ""
    let sk = $env.LAKEKEEPER__S3_SECRET_KEY? | default ""
    if ($ak | is-not-empty) and ($sk | is-not-empty) {
        let wh = $env.LAKEKEEPER__WAREHOUSE? | default "default"
        print $"Creating warehouse: ($wh)"
        mut wh_ok = false
        for attempt in 1..5 {
            let r = (
                http post --allow-errors -t application/json
                $"http://localhost:($port)/management/v1/warehouse"
                {
                    "warehouse-name": $wh,
                    "delete-profile": { type: "hard" },
                    "storage-credential": {
                        type: "s3", "credential-type": "access-key",
                        "aws-access-key-id": $ak,
                        "aws-secret-access-key": $sk
                    },
                    "storage-profile": {
                        type: "s3",
                        bucket: ($env.LAKEKEEPER__S3_BUCKET? | default ""),
                        region: ($env.LAKEKEEPER__S3_REGION? | default ""),
                        flavor: "s3-compat",
                        endpoint: ($env.LAKEKEEPER__S3_ENDPOINT? | default ""),
                        "path-style-access": false,
                        "sts-enabled": false,
                        "key-prefix": ($env.LAKEKEEPER__S3_KEY_PREFIX? | default "")
                    }
                }
            )
            let code = $r.status_code? | default 0
            if $code in [200 201] {
                print "Warehouse created"; $wh_ok = true; break
            } else if $code == 409 {
                print "Warehouse already exists"; $wh_ok = true; break
            }
            print $"Warehouse attempt ($attempt) failed (HTTP ($code | into string))"
            sleep (1sec * $attempt)
        }
        if not $wh_ok { exit 1 }
    } else {
        print "WARNING: LAKEKEEPER__S3_ACCESS_KEY/LAKEKEEPER__S3_SECRET_KEY not set, skipping warehouse creation."
    }

    touch $flag
    print "Bootstrap complete."
}
