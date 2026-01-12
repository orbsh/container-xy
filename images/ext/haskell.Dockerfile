ARG BASEIMAGE=ghcr.io/fj0r/xy:z
FROM ${BASEIMAGE}

ARG STACK_FLAGS="--local-bin-path=/usr/local/bin --no-interleaved-output"
ARG STACK_INFO_URL="https://www.stackage.org/lts"
ARG MESSAGE=''
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1

ENV GHCUP_INSTALL_BASE_PREFIX=/opt GHCUP_ROOT=/opt/.ghcup
ENV STACK_ROOT=/opt/stack
ENV PATH=${GHCUP_ROOT}/bin:$PATH


RUN set -eux \
  ; mkdir -p ${GHCUP_ROOT}/bin \
  ; mkdir -p ${STACK_ROOT} \
  ; curl --retry 3 -fsSLo ${GHCUP_ROOT}/bin/ghcup https://downloads.haskell.org/~ghcup/x86_64-linux-ghcup \
  ; chmod +x ${GHCUP_ROOT}/bin/ghcup \
  ; ghcup install stack \
  ; ghcup install cabal \
  ; stack config set system-ghc --global true \
  ; stack config set install-ghc --global false \
  \
  ; ghc_ver=$(curl --retry 3 -fsSL ${STACK_INFO_URL} | rg '<h1>LTS Haskell.+\(.*?([0-9\.]+)\)' -or '$1') \
  ; ghcup -s '["GHCupURL", "StackSetupURL"]' install ghc $ghc_ver \
  \
  ; for i in \
      tmp cache trash logs \
  ; do \
      du -hd 1 "${GHCUP_ROOT}/${i}" ;\
      rm -rf "${GHCUP_ROOT}/${i}/*" ;\
    done \
  \
  ; rm -rf ${GHCUP_ROOT}/ghc/${ghc_ver}/share \
  ; nu -c "open ${STACK_ROOT}/config.yaml | merge {allow-different-user: true, allow-newer: true, recommend-stack-upgrade: false} | collect { \$in | save -f ${STACK_ROOT}/config.yaml }" \
  ;

RUN set -eux \
  ; mkdir -p ${LS_ROOT}/haskell/tmp \
  ; hls_version=$(curl --retry 3 -fsSL https://api.github.com/repos/haskell/haskell-language-server/releases/latest | jq -r '.tag_name') \
  ; ghc_version=$(stack ghc -- --numeric-version) \
  ; curl --retry 3 -fsSL https://downloads.haskell.org/~hls/haskell-language-server-${hls_version}/haskell-language-server-${hls_version}-x86_64-linux-unknown.tar.xz \
  | tar Jxvf - -C ${LS_ROOT}/haskell/tmp --strip-components=1 \
  ; cd ${LS_ROOT}/haskell/tmp \
  ; files="bin/haskell-language-server-${ghc_version} \
           bin/haskell-language-server-wrapper \
           lib/${ghc_version}" \
  ; nu -c "'$files' | split row -r '\\s+' \
    | each {|x| if (\$x | path exists) { \
            let tg = ([.., (\$x | path dirname)] | path join); \
            mkdir \$tg; \
            cp -r \$x \$tg \
        } \
    }" \
  ; cd .. \
  ; rm -rf tmp \
  ; find ${LS_ROOT}/haskell -type f -exec grep -IL . "{}" \; | xargs -L 1 strip -s \
  ;


RUN set -eux \
  ; stack install ${STACK_FLAGS} \
      ghcid implicit-hie \
      # haskell-dap ghci-dap haskell-debug-adapter \
      deepseq call-stack primitive ghc-prim \
      template-haskell aeson yaml  \
      classy-prelude base binary bytestring text \
      containers unordered-containers vector transformers \
      time directory filepath \
      shelly process unix \
      req websockets network servant wai warp network-uri \
      # extensible-effects extensible-exceptions
      lens recursion-schemes free \
      megaparsec Earley \
      singletons \
      monad-par parallel async stm \
      regex-base regex-posix regex-compat \
      pipes conduit machines \
      QuickCheck falsify hspec \
      # hmatrix linear \
      # statistics ad integration
      # parsers dimensional
      # scotty
      # http-conduit HTTP html taggy multipart \
      # optparse-applicative \
      # clock hpc pretty \
      # array hashtables dlist \
      # hashable  \
      # fixed mtl fgl \
      # boomerang \
      # bound unbound-generics transformers-compat \
      # syb uniplate \
      # persistent memory cryptonite \
      # mwc-random MonadRandom random \
      # katip monad-logger \
  ; rm -rf ${STACK_ROOT}/pantry/hackage/* \
  ; chown ${MASTER}:${MASTER} -R ${STACK_ROOT} \
  ; opwd=$PWD \
  ; cd /home/${MASTER} \
  ; stack new ${STACK_FLAGS} hello-rio rio \
  ; cd hello-rio \
  ; gen-hie > hie.yaml \
  ; cd /home/${MASTER} \
  ; chown ${MASTER}:${MASTER} -R hello-rio \
  ; stack new ${STACK_FLAGS} hello-haskell \
  ; cd hello-haskell \
  ; gen-hie > hie.yaml \
  ; cd /home/${MASTER} \
  ; chown ${MASTER}:${MASTER} -R hello-haskell \
  ; cd $opwd \
  ; for x in config.yaml \
             templates \
             stack.sqlite3.pantry-write-lock \
             pantry/pantry.sqlite3.pantry-write-lock \
  ; do chmod 777 ${STACK_ROOT}/$x; done \
  ; chmod 777 -R ${STACK_ROOT}/global-project \
  ;

COPY assets/ghci /home/${MASTER}/.ghci
