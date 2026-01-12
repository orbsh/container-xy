#!/usr/bin/env nu

use init.nu pueue-extend

# s3fs if s3_id=mount,user,endpoint,region,bucket,accesskey,secretkey,opts...
# opts: nonempty,use_path_request_style,use_xattr,a=1,b=2
def run_s3 [s3_id: string, s3_args: string] {
    let arr = $s3_args | split row ","

    let o = [
        mount_point
        user
        endpoint
        region
        bucket
        access_key
        secret_key
    ]
    | enumerate
    | reduce -f {} {|i, a|
        $a | insert $i.item ($arr | get $i.index)
    }

    let raw_opts = $arr | slice 7..
    let opt_args = $raw_opts | each { |it|
        if ($it | str contains "=") {
            ["-o" $it]
        } else {
            ["-o" $it]
        }
    } | flatten

    let safe_name = $o.mount_point | str replace -a "/" "_"
    let auth_dir = "/.s3fs-passwd"
    let auth_file = $"($auth_dir)/($safe_name)"

    if not ($auth_dir | path exists) {
        sudo mkdir $auth_dir
    }

    print $"Generating authfile: ($auth_file)"
    $"($o.access_key):($o.secret_key)\n" | sudo tee $auth_file | ignore
    sudo chmod "go-rwx" $auth_file
    sudo chown $o.user $auth_file

    sudo mkdir -p $o.mount_point
    sudo chown $o.user $o.mount_point

    let region_opts = if ($o.region | is-empty) {
        ["-o" "use_path_request_style"]
    } else {
        ["-o" $"endpoint=($o.region)"]
    }

    let s3fs_cmd = [
        "sudo" "-u" $o.user "s3fs" "-f"
        ...$opt_args
        "-o" $"bucket=($o.bucket)"
        "-o" $"passwd_file=($auth_file)"
        "-o" $"url=($o.endpoint)"
        ...$region_opts
        $o.mount_point
    ] | str join " "

    print $"Starting s3fs ($s3_id) for ($o.mount_point)"

    pueue add --group default -l $"s3fs_($s3_id)" -- $"($s3fs_cmd)"
}

let s3_configs = $env | transpose k v | where k starts-with "s3_"

if ($s3_configs | is-not-empty) {
    pueue-extend default ($s3_configs | length)
    for r in $s3_configs {
        let s3_id = ($r.k | str replace "s3_" "")
        print $"Configuring S3FS: ($s3_id)"
        run_s3 $s3_id $r.v
    }
}
