use ../libs *

export def --env main [context: record = {}] {
    { from: $'($context.image):latest' }
    | build --no-commit --expose {|ctx|
        pkg install [
            base-devel
            curl
            git
        ]
        let version = curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | from json | get tag_name
        trace o -p neovim-version $version
        let url = $"https://github.com/neovim/neovim/releases/download/($version)/nvim-linux-x86_64.tar.gz"
        with-mount {|new, old|
            mkdir target
            cd target
            let target = pwd
            trace o -p download $url
            curl -fsSL $url | tar -zxf - -C . --strip-components=1
            mkdir etc/nvim
            let gurl = 'https://github.com/fj0r/nvim-lua.git'
            trace o -p config $gurl
            git clone --depth=3 $gurl etc/nvim
            trace o -p setup-extensions
            bin/nvim -u etc/nvim/init.lua --headless "+Lazy! sync" +qa
            'rm -rf etc/nvim/lazy/packages/*/.git'
        }
    }
}
