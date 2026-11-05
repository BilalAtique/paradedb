-- Fork-only check for #6640; not part of the upstream PR.
-- Plans with the custom scan on, over the tables that explore-rows.sql created.
\set VERBOSITY terse
SET max_parallel_workers_per_gather = 0;

EXPLAIN (COSTS OFF) SELECT id, kind FROM ip WHERE id @@@ paradedb.all() ORDER BY id;
EXPLAIN (COSTS OFF) SELECT id, kind FROM ip WHERE kind ||| 'apple' ORDER BY id DESC LIMIT 1;
EXPLAIN (COSTS OFF) SELECT count(*) FROM ip WHERE kind ||| 'apple cherry';
EXPLAIN (COSTS OFF) SELECT id, kind FROM ONLY ip WHERE kind ||| 'apple' ORDER BY id;
EXPLAIN (COSTS OFF) UPDATE ip SET kind = kind || ' pie' WHERE kind ||| 'apple';
EXPLAIN (COSTS OFF) DELETE FROM ip WHERE kind ||| 'apple';
EXPLAIN (COSTS OFF) SELECT ip.id, other.id FROM ip JOIN other ON ip.id = other.ip_id
WHERE ip.kind ||| 'apple' ORDER BY 1, 2;
SET paradedb.enable_join_custom_scan = on;
EXPLAIN (COSTS OFF) SELECT ip.id, other.id FROM ip JOIN other ON ip.id = other.ip_id
WHERE ip.kind ||| 'apple' AND other.note ||| 'x y' ORDER BY 1, 2 LIMIT 10;
RESET paradedb.enable_join_custom_scan;
EXPLAIN (COSTS OFF) SELECT id, kind FROM np WHERE kind ||| 'apple' ORDER BY id;
EXPLAIN (COSTS OFF) SELECT id FROM g0 WHERE kind ||| 'apple' ORDER BY id;
EXPLAIN (COSTS OFF) SELECT id, kind FROM ep WHERE kind ||| 'apple' ORDER BY id;
