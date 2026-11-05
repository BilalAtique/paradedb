CREATE EXTENSION IF NOT EXISTS pg_search CASCADE;
DROP TABLE IF EXISTS messages;
CREATE TABLE messages (id bigint PRIMARY KEY, channel int, body text);
CREATE INDEX messages_idx ON messages USING paradedb (id, channel, body);
-- Snowflake-style ids, as Discord and Twitter generate them.
INSERT INTO messages VALUES
    (1234567890123456789, 1, 'payment failed'),
    (1234567890123456001, 1, 'payment ok');

SELECT MAX(id), MIN(id) FROM messages WHERE body ||| 'payment';

SELECT * FROM messages
WHERE id = (SELECT MAX(id) FROM messages WHERE body ||| 'payment');

SELECT channel, MAX(id) FROM messages WHERE body ||| 'payment' GROUP BY channel;

EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT MAX(id), MIN(id) FROM messages WHERE body ||| 'payment';

SET paradedb.enable_aggregate_custom_scan = off;
SELECT MAX(id), MIN(id) FROM messages WHERE body ||| 'payment';
SELECT channel, MAX(id) FROM messages WHERE body ||| 'payment' GROUP BY channel;
