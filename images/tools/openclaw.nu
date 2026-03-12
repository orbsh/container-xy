use ../../bx *


export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | merge { tag: openclaw }
    | build {|ctx|
        # pkg install [sudo cronie]

        pkg npm install [openclaw]
        copy images/tools/entrypoint/openclaw.nu /entrypoint/openclaw.nu

        conf expose [10267]
        conf cmd ['srv']
    }
}
