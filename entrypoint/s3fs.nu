#!/usr/bin/env nu

use libs/tasks.nu

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

    let cmd = [
        "sudo" "-u" $o.user "s3fs" "-f"
        ...$opt_args
        "-o" $"bucket=($o.bucket)"
        "-o" $"passwd_file=($auth_file)"
        "-o" $"url=($o.endpoint)"
        ...$region_opts
        $o.mount_point
    ]
    | str join " "

    {
        tag: $"s3fs_($s3_id)"
        msg: $"Starting s3fs ($s3_id) for ($o.mount_point)"
        cmd: $cmd
    }
}

let s3_configs = $env | transpose k v | where k starts-with "s3_"

if ($s3_configs | is-not-empty) {
    $s3_configs
    | each {|r|
        let s3_id = ($r.k | str replace "s3_" "")
        run_s3 $s3_id $r.v
    }
    | tasks spawn ...$in
}
