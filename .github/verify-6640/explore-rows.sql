-- Fork-only check for #6640; not part of the upstream PR.
-- The workflow runs this file once with the custom scan on and once with it off,
-- each in a fresh database, and diffs the two outputs.
\set VERBOSITY terse
CREATE EXTENSION IF NOT EXISTS pg_search CASCADE;
SET max_parallel_workers_per_gather = 0;

-- Every table has its own index.
CREATE TABLE ip (id SERIAL PRIMARY KEY, kind TEXT);
CREATE TABLE ic () INHERITS (ip);
INSERT INTO ip (kind) VALUES ('apple'), ('banana');
INSERT INTO ic (kind) VALUES ('cherry'), ('apple');
CREATE INDEX ip_idx ON ip USING paradedb (id, kind);
CREATE INDEX ic_idx ON ic USING paradedb (id, kind);
ANALYZE ip;
ANALYZE ic;

SELECT id, kind FROM ip WHERE id @@@ paradedb.all() ORDER BY id;
SELECT id, kind FROM ip WHERE kind ||| 'apple' ORDER BY id;
SELECT id, kind FROM ip WHERE kind ||| 'apple' ORDER BY id DESC LIMIT 1;
SELECT count(*) FROM ip WHERE kind ||| 'apple cherry';
SELECT DISTINCT kind FROM ip WHERE kind ||| 'apple cherry' ORDER BY kind;
SELECT kind, count(*) FROM ip WHERE kind ||| 'apple cherry' GROUP BY kind ORDER BY kind;
SELECT id, kind FROM ONLY ip WHERE kind ||| 'apple' ORDER BY id;
SELECT id, kind FROM ic WHERE kind ||| 'apple' ORDER BY id;
SELECT tableoid::regclass AS tbl, id FROM ip WHERE kind ||| 'apple' ORDER BY id;
SELECT id, pdb.score(id) > 0 AS scored FROM ip WHERE kind ||| 'apple' ORDER BY id;
SELECT id, pdb.snippet(kind) FROM ip WHERE kind ||| 'apple' ORDER BY id;

-- Writes on the parent.
BEGIN;
WITH u AS (UPDATE ip SET kind = kind || ' pie' WHERE kind ||| 'apple' RETURNING id, kind)
SELECT id, kind FROM u ORDER BY id;
SELECT tableoid::regclass AS tbl, id, kind FROM ip ORDER BY id;
ROLLBACK;
BEGIN;
WITH d AS (DELETE FROM ip WHERE kind ||| 'apple' RETURNING id)
SELECT id FROM d ORDER BY id;
SELECT tableoid::regclass AS tbl, id, kind FROM ip ORDER BY id;
ROLLBACK;
BEGIN;
DELETE FROM ip WHERE id @@@ paradedb.all();
SELECT tableoid::regclass AS tbl, id, kind FROM ip ORDER BY id;
ROLLBACK;

-- A join with the parent.
CREATE TABLE other (id INT PRIMARY KEY, ip_id INT, note TEXT);
INSERT INTO other VALUES (1, 1, 'x'), (2, 4, 'y'), (3, 3, 'z');
CREATE INDEX other_idx ON other USING paradedb (id, ip_id, note);
ANALYZE other;
SELECT ip.id, other.id FROM ip JOIN other ON ip.id = other.ip_id
WHERE ip.kind ||| 'apple' ORDER BY 1, 2;
SET paradedb.enable_join_custom_scan = on;
SELECT ip.id, other.id FROM ip JOIN other ON ip.id = other.ip_id
WHERE ip.kind ||| 'apple' AND other.note ||| 'x y' ORDER BY 1, 2 LIMIT 10;
RESET paradedb.enable_join_custom_scan;

-- A child without its own index.
CREATE TABLE np (id SERIAL PRIMARY KEY, kind TEXT);
CREATE TABLE nc () INHERITS (np);
INSERT INTO np (kind) VALUES ('apple'), ('banana');
INSERT INTO nc (kind) VALUES ('cherry'), ('apple');
CREATE INDEX np_idx ON np USING paradedb (id, kind);
ANALYZE np;
ANALYZE nc;
SELECT id, kind FROM np WHERE kind ||| 'apple' ORDER BY id;
SELECT id, kind FROM np WHERE id @@@ paradedb.all() ORDER BY id;

-- Three levels, every table indexed.
CREATE TABLE g0 (id SERIAL PRIMARY KEY, kind TEXT);
CREATE TABLE g1 () INHERITS (g0);
CREATE TABLE g2 () INHERITS (g1);
INSERT INTO g0 (kind) VALUES ('apple'), ('banana');
INSERT INTO g1 (kind) VALUES ('apple'), ('banana');
INSERT INTO g2 (kind) VALUES ('apple'), ('banana');
CREATE INDEX g0_idx ON g0 USING paradedb (id, kind);
CREATE INDEX g1_idx ON g1 USING paradedb (id, kind);
CREATE INDEX g2_idx ON g2 USING paradedb (id, kind);
ANALYZE g0;
ANALYZE g1;
ANALYZE g2;
SELECT id FROM g0 WHERE kind ||| 'apple' ORDER BY id;
SELECT id FROM g1 WHERE kind ||| 'apple' ORDER BY id;
SELECT id FROM ONLY g1 WHERE kind ||| 'apple' ORDER BY id;

-- An empty parent: every row is in the child.
CREATE TABLE ep (id SERIAL PRIMARY KEY, kind TEXT);
CREATE TABLE ec () INHERITS (ep);
INSERT INTO ec (kind) VALUES ('apple'), ('banana');
CREATE INDEX ep_idx ON ep USING paradedb (id, kind);
CREATE INDEX ec_idx ON ec USING paradedb (id, kind);
ANALYZE ep;
ANALYZE ec;
SELECT id, kind FROM ep WHERE kind ||| 'apple' ORDER BY id;
