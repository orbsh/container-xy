## text search

```sql
CREATE EXTENSION IF NOT EXISTS zhparser;
CREATE TEXT SEARCH CONFIGURATION chinese_zh (PARSER = zhparser);
-- ALTER TEXT SEARCH CONFIGURATION testzhcfg ADD MAPPING FOR n,v,a,i,e,l WITH simple;
ALTER TEXT SEARCH CONFIGURATION chinese_zh
ADD MAPPING FOR a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
WITH simple;
SELECT * FROM ts_debug('chinese_zh', '这是一个测试句子，用来验证PostgreSQL中文分词。');
```

```sql
CREATE EXTENSION pg_textsearch;
CREATE TABLE documents (id bigserial PRIMARY KEY, content text);
INSERT INTO documents (content) VALUES
    ('PostgreSQL is a powerful database system'),
    ('BM25 is an effective ranking function'),
    ('Full text search with custom scoring');
```

```sql
CREATE INDEX docs_idx ON documents USING bm25(content) WITH (text_config='public.chinese_zh');
```

- text_config='english'

```sql
SELECT * FROM documents
ORDER BY content <@> 'database system'
LIMIT 5;
```

```sql
SELECT * FROM documents
WHERE content <@> to_bm25query('search terms', 'docs_idx') < -5.0
ORDER BY content <@> 'search terms'
LIMIT 10;
```

## RRF

```sql
WITH keyword_search AS (
    SELECT id,
           RANK() OVER (ORDER BY content <@> query) as kw_rank
    FROM documents
),
vector_search AS (
    SELECT id,
           RANK() OVER (ORDER BY embedding <=> '[...你的查询向量...]') as vec_rank
    FROM documents
)
SELECT
    d.id,
    d.content,
    -- RRF
    (1.0 / (60 + kw.kw_rank)) + (1.0 / (60 + vec.vec_rank)) as rrf_score
FROM documents d
LEFT JOIN keyword_search kw ON d.id = kw.id
LEFT JOIN vector_search vec ON d.id = vec.id
WHERE kw.id IS NOT NULL OR vec.id IS NOT NULL -- 至少在一个搜索中出现
ORDER BY rrf_score DESC
LIMIT 5;
```
