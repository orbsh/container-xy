use ../../libs *

export def main [context: record = {}] {
    {
        from: $'($context.image):z'
        user: master
        workdir: /home/master
    }
    | merge $context
    | build {|ctx|
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
        }
          
    }
}
