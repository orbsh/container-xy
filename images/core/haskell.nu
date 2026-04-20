use ../../bx *
use ../../bx/utils.nu

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        let ghcup_root = '/opt/.ghcup'
        conf env {
            BOOTSTRAP_HASKELL_NONINTERACTIVE: '1'
            GHCUP_INSTALL_BASE_PREFIX:/opt
            GHCUP_ROOT: $ghcup_root
            STACK_ROOT: /opt/stack
        }
        conf path [($ghcup_root)/bin]

        pkg install [
            ghc cabal-install
            stack
            haskell-language-server
            stylish-haskell hlint
        ]

        utils resolve-stack [stacks haskell] [
            dev core collections
            io data codec web lens parser
            regex concurrency streaming
            # prelude effects testing science cli logging
            # generic persistence random scraping
        ] []
        | str join ' '
        | print $"skipped: ($in)"
        # | run [
        #     'stack update'
        #     $'stack install --local-bin-path=/usr/local/bin --no-interleaved-output ($in)'
        #     'stack clean'
        # ]

        with-mount {
            r#'
            :set prompt "λ: "
            :set prompt-cont "   | "
            :set +t
            :set +m
            :set stop :list
            :def! hlint return . const (":! hlint .")
            :def! hoogle \x -> return $ ":!hoogle \"" ++ x ++ "\""
            :def! doc \x -> return $ ":!hoogle --info \"" ++ x ++ "\""
            :set -XDuplicateRecordFields
            :set -XDisambiguateRecordFields
            :set -XOverloadedRecordDot
            -- :set -XRebindableSyntax
            :set -XMultiWayIf
            :set -XRankNTypes
            :set -XTypeFamilies
            :set -XTypeFamilyDependencies
            :set -XTypeOperators
            :set -XGADTs
            :set -XDeriveDataTypeable
            :set -XDataKinds
            :set -XKindSignatures
            :set -XConstraintKinds
            :set -XFlexibleContexts
            :set -XFlexibleInstances
            :set -XUndecidableInstances
            :set -XMagicHash
            :set -XTupleSections
            :set -XMultiParamTypeClasses
            :set -XFunctionalDependencies
            :set -XViewPatterns
            :set -XOverloadedStrings
            :set -XExistentialQuantification
            :set -XScopedTypeVariables
            :set -XArrows
            :set -XImplicitParams
            :set -XTemplateHaskell
            :set -XDefaultSignatures
            :set -XDeriveGeneric
            :set -XDeriveAnyClass
            :set -XMonadComprehensions
            -- :set -XNoMonomorphismRestriction
            :set -XPolyKinds
            :m +Language.Haskell.TH
            -- :m +Flow
            :m +Data.Ratio
            :m +Data.Proxy
            :m +Data.Function
            :m +Data.Array
            :m +Data.List
            :m +Data.Maybe
            :m +Data.Word
            :m +Data.Monoid
            :m +Data.IORef
            :m +Control.Concurrent
            :m +Control.Applicative
            :m +Control.Monad
            :m +Control.Monad.State
            :m +Control.Monad.Reader
            :m +Control.Monad.Identity
            :m +Control.Arrow
            :m +System.Environment
            :m +System.IO
            :m +Data.Time
            '#
            | str trim
            | str replace -rma $'^ {12}' ''
            | save -f root/.ghci
        }

    }
}
