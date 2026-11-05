-- Each block runs the query through ParadeDB, then again with the ParadeDB scan turned off.
\set ON_ERROR_STOP 0
\pset footer off
SET paradedb.planner_warnings = off;
SELECT extversion FROM pg_extension WHERE extname = 'pg_search';

-- 1. GROUP BY on a real column fails when a group key is a whole number.
DROP TABLE IF EXISTS items;
CREATE TABLE items (id int PRIMARY KEY, description text, rating real);
INSERT INTO items VALUES (1, 'running shoes', 4.5), (2, 'running shoes', 4.5), (3, 'running shoes', 5);
CREATE INDEX items_idx ON items USING paradedb (id, description, rating);
SELECT rating, count(*) FROM items WHERE description ||| 'shoes' GROUP BY rating ORDER BY rating;
EXPLAIN (COSTS OFF) SELECT rating, count(*) FROM items WHERE description ||| 'shoes' GROUP BY rating ORDER BY rating;
SET paradedb.enable_aggregate_custom_scan = off;
SELECT rating, count(*) FROM items WHERE description ||| 'shoes' GROUP BY rating ORDER BY rating;
RESET paradedb.enable_aggregate_custom_scan;

-- 2. GROUP BY on a float column drops the rows of one group when it holds both -0 and 0.
DROP TABLE IF EXISTS readings;
CREATE TABLE readings (id int PRIMARY KEY, sensor text, delta float8);
INSERT INTO readings VALUES (1, 'a', '-0'), (2, 'a', 0), (3, 'a', 0), (4, 'a', 1);
CREATE INDEX readings_idx ON readings USING paradedb (id, sensor, delta);
SELECT delta, count(*) FROM readings WHERE sensor ||| 'a' GROUP BY delta ORDER BY delta;
SELECT pdb.agg('{"terms": {"field": "delta"}}') FROM readings WHERE sensor ||| 'a';
EXPLAIN (COSTS OFF) SELECT delta, count(*) FROM readings WHERE sensor ||| 'a' GROUP BY delta ORDER BY delta;
SET paradedb.enable_aggregate_custom_scan = off;
SELECT delta, count(*) FROM readings WHERE sensor ||| 'a' GROUP BY delta ORDER BY delta;
RESET paradedb.enable_aggregate_custom_scan;

-- 3. A pushed-down float filter treats -0 and 0 as different values.
SELECT array_agg(id ORDER BY id) AS eq_zero FROM readings WHERE id @@@ pdb.all() AND delta = 0;
SELECT array_agg(id ORDER BY id) AS lt_zero FROM readings WHERE id @@@ pdb.all() AND delta < 0;
SELECT array_agg(id ORDER BY id) AS ge_zero FROM readings WHERE id @@@ pdb.all() AND delta >= 0;
EXPLAIN (COSTS OFF) SELECT id FROM readings WHERE id @@@ pdb.all() AND delta = 0;
SET paradedb.enable_custom_scan = off;
SELECT array_agg(id ORDER BY id) AS eq_zero FROM readings WHERE delta = 0;
SELECT array_agg(id ORDER BY id) AS lt_zero FROM readings WHERE delta < 0;
SELECT array_agg(id ORDER BY id) AS ge_zero FROM readings WHERE delta >= 0;
RESET paradedb.enable_custom_scan;

-- 4. MIN and MAX over bigint return a value that is not in the table above 2^53.
DROP TABLE IF EXISTS events;
CREATE TABLE events (id bigint PRIMARY KEY, body text, flag bool);
INSERT INTO events VALUES (9007199254740993, 'a', true), (1, 'a', false), (-9007199254740993, 'a', NULL), (5, 'a', true);
CREATE INDEX events_idx ON events USING paradedb (id, body, flag);
SELECT max(id), min(id) FROM events WHERE body ||| 'a';
SELECT max(id) = 9007199254740993 AS max_is_exact FROM events WHERE body ||| 'a';
EXPLAIN (COSTS OFF) SELECT max(id), min(id) FROM events WHERE body ||| 'a';
SET paradedb.enable_aggregate_custom_scan = off;
SELECT max(id), min(id) FROM events WHERE body ||| 'a';
RESET paradedb.enable_aggregate_custom_scan;

-- 5. GROUP BY on a bool column puts the NULL group first under ORDER BY ... ASC (NULLS LAST).
SELECT flag, count(*) FROM events WHERE body ||| 'a' GROUP BY flag ORDER BY flag;
SELECT flag, count(*) FROM events WHERE body ||| 'a' GROUP BY flag ORDER BY flag DESC NULLS FIRST;
SELECT flag, count(*) FROM events WHERE body ||| 'a' GROUP BY flag ORDER BY flag LIMIT 2;
EXPLAIN (COSTS OFF) SELECT flag, count(*) FROM events WHERE body ||| 'a' GROUP BY flag ORDER BY flag LIMIT 2;
SET paradedb.enable_aggregate_custom_scan = off;
SELECT flag, count(*) FROM events WHERE body ||| 'a' GROUP BY flag ORDER BY flag;
SELECT flag, count(*) FROM events WHERE body ||| 'a' GROUP BY flag ORDER BY flag LIMIT 2;
RESET paradedb.enable_aggregate_custom_scan;
