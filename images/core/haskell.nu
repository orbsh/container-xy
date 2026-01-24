use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):latest'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
        pkg install [
            ghc cabal-install
            # stack
            haskell-language-server
            stylish-haskell hlint
        ]
        [
            ghcid # implicit-hie
            # haskell-dap ghci-dap haskell-debug-adapter
            deepseq call-stack primitive ghc-prim
            template-haskell aeson yaml
            classy-prelude base binary bytestring text
            containers unordered-containers vector transformers
            time directory filepath
            shelly process unix
            req websockets network servant wai warp network-uri
            # extensible-effects extensible-exceptio
            lens recursion-schemes free
            megaparsec # Earley
            singletons
            monad-par parallel async stm
            regex-base regex-posix regex-compat
            pipes conduit machines
            # QuickCheck falsify hspec
            # hmatrix linear
            # statistics ad integrati
            # parsers dimension
            # scot
            http-conduit html taggy multipart
            # optparse-applicative
            # clock hpc pretty
            # array hashtables dlist
            # hashable
            # fixed mtl fgl
            # boomerang
            # bound unbound-generics transformers-compat
            # syb uniplate
            # persistent memory cryptonite
            # mwc-random MonadRandom random
            # katip monad-logger
        ]
        | str join ' '
        # | run [
        #     'cabal update'
        #     $'cabal install ($in)'
        #     'cabal clean'
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
