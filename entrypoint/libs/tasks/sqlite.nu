use ../info.nu

const DB = '/var/lib/tasks.db'

export def log [id] {
}

export def init [] {
    {_: '.'} | into sqlite -t _ $DB
    open $DB | query db "DROP TABLE _;"
    open $DB | query db "
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY,
            grp TEXT default 'default',
            tag TEXT NOT NULL UNIQUE,
            cmd TEXT,
            msg TEXT,
            created TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now'))
        );
    "
    open $DB | query db "
        CREATE TABLE IF NOT EXISTS procs (
            tid INTEGER REFERENCES tasks(id),
            pid INTEGER NOT NULL UNIQUE
        );
    "
}

export def spawn [
    ...tasks
    --group(-g): string = 'default'
] {
    if ($tasks | is-empty) { return }
    for t in $tasks {
        if ($t.msg | is-not-empty) { info $t.msg }
        let task_id = if ($env.SPAWN_VIA_BASH? | is-empty) {
            job spawn -d $t.tag {
                let cmd = $t.cmd | split row -r '\s+'
                let bin = $cmd.0
                let args = $cmd | skip 1
                job spawn -d $t.tag {
                    run-external $bin ...$args out+err>| tee { save -f /proc/1/fd/1 }
                }
            }
        } else {
            job spawn -d $t.tag {
                bash -c $'($t.cmd) |& tee /proc/1/fd/1'
            }
        }
        let stmt = {
            id: $task_id
            grp: $group
            tag: $t.tag
            cmd: $t.cmd
            msg: $t.msg?
        }
        | format pattern "INSERT INTO tasks (id, grp, tag, cmd, msg) values ({id}, '{grp}', '{tag}', '{cmd}', '{msg}');"
        open $DB | query db $stmt

        let pids = job list
        | where id == $task_id
        | get 0.pids

        if ($pids | is-not-empty) {
            let stmt = $pids
            | each {|x|
                {
                    tid: $task_id
                    pid: $x
                }
            }
            | format pattern "({tid}, {pid})"
            | str join ', '
            | $"INSERT INTO procs \(tid, pid\) VALUES ($in);"

            open $DB | query db $stmt
        }
    }
}

export def wait [
    --group(-g): string = 'default'
] {
    let interval = $env.CHECK_INTERVAL? | default '5sec' | into duration
    let pids = open $DB | query db $"select p.pid as pid from tasks as t join procs as p on p.tid = t.id where grp = '($group)'"
    let pids = $pids | get pid | each { [--pid $in] } | flatten
    print pids:($pids)

    tail -f /dev/null ...$pids
    print '...'
}

export def list [] {

}
