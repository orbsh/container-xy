use utils.nu *

export def timezone [timezone] {
    run [
        $'ln -sf /usr/share/zoneinfo/($timezone) /etc/localtime'
        $'echo "($timezone)" > /etc/timezone'
    ]
}

export def git [author] {
    run [
        'git config --global pull.rebase false'
        'git config --global init.defaultBranch main'
        $'git config --global user.name "($author)"'
        $'git config --global user.email "($author)@container"'
    ]
}

export def sudo [] {
    run [
        `sed -i 's/# \(%.*NOPASSWD.*\)/&\n\1/' /etc/sudoers`
    ]
}

export def master [
    user: string
    workdir: string
    config_dir: string
] {
    run [
        $'useradd -mU -G wheel,root ($user)'
        $'mkdir -p ($workdir)'
        $'chown ($user):($user) -R ($workdir)'
        $'mkdir -p ($config_dir)'
        $'chown ($user):($user) -R ($config_dir)'
    ]
}
