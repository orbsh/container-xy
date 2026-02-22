use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    sync pg_duckdb {
        repo: 'duckdb/pg_duckdb'
        version: ['substr 1']
    } $tags {|cx|
        {
            timezone: Asia/Shanghai
        }
        | merge $context
        | merge { from: 'scratch', tag: $cx.tag }
        | build {|ctx|
            {
                from: $"($context.image):($pgrx)"
            }
            | build --no-commit {|ctx1|
            }
        }
    }
}
