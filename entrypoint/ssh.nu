#!/usr/bin/env nu
use init.nu [pueue-extend now]

# user:uid:gid:comment
def set_user [user_info: string, pubkey: string] {
    let arr = $user_info | split row ":"
    let name = $arr | get 0
    let root = $name == 'root'
    let sudo = $env.SSH_SUDO_GROUP? | default 'sudo'

    let uid = if $root { "0" } else { $arr | get 1? | default "1000" }
    let gid = if $root { "0" } else { $arr | get 2? | default ($arr | get 1?) | default "1000" }
    let comment = $arr | get 3? | default $name

    let shell = [
        "/bin/zsh"
        "/bin/bash"
        "/bin/sh"
    ] | where { |it| $it | path exists } | first

    if not $root {
        print $"(now) setup user: ($name)"

        if (sudo getent group $name | is-empty) {
            sudo groupadd -g $gid $name
        }
        if (sudo getent passwd $name | is-empty) {
            sudo useradd -m -u $uid -g $gid -G $sudo -s $shell -c $comment $name
        }
    }

    let home_dir = (sudo getent passwd $name | split row ":" | get 5)

    let profile = $"($home_dir)/.profile"
    $"\nPATH=($env.PATH)\n" | sudo tee -a $profile | ignore

    let ssh_dir = $"($home_dir)/.ssh"
    if not ($ssh_dir | path exists) {
        sudo mkdir $ssh_dir
    }
    $"ssh-ed25519 ($pubkey)\n" | sudo tee -a $"($ssh_dir)/authorized_keys" | ignore
    sudo chown -R $"($name):($name)" $ssh_dir
    sudo chmod -R "go-rwx" $ssh_dir
}

def init_ssh [config] {
    if ($env.SSH_HOSTKEY_ED25519? != null) {
        $env.SSH_HOSTKEY_ED25519 | decode base64 | sudo tee /etc/dropbear/dropbear_ed25519_host_key | ignore
    }

    for r in $config {
        let user_info = ($r.k | str replace "ed25519_" "")
        set_user $user_info $r.v
    }
}

def run_ssh [] {
    let timeout_args = if ($env.SSH_TIMEOUT? != null) {
        print $"(now) Starting dropbear with a timeout of ($env.SSH_TIMEOUT) seconds"
        ["-K" $env.SSH_TIMEOUT "-I" $env.SSH_TIMEOUT]
    } else {
        print $"(now) Starting dropbear"
        []
    }

    let cmd = [
        "sudo" "dropbear" "-REFems" "-p" "22"
        ...$timeout_args
    ] | str join " "

    pueue-extend default 1
    pueue add --group default -l "sshd" -- $"($cmd)"
}

let ssh_config = $env | transpose k v | where k starts-with 'ed25519_'

if ($ssh_config | is-not-empty) {
    if not ('/etc/dropbear' | path exists) {
        sudo mkdir /etc/dropbear
    }
    init_ssh $ssh_config
    run_ssh
}
