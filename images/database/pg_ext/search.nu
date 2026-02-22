use ./libs.nu *
use ../../../libs *

export def main [pgrx tags context] {
    sync pg_search {
        repo: 'duckdb/pg_duckdb'
        version: []
    } $tags {|cx|
    }
}
