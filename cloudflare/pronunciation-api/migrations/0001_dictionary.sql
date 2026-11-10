CREATE TABLE IF NOT EXISTS dictionary_metadata (
 version INTEGER PRIMARY KEY CHECK(version>0), updated_at TEXT NOT NULL,
 schema_version INTEGER NOT NULL CHECK(schema_version=1),
 rule_count INTEGER NOT NULL CHECK(rule_count BETWEEN 1 AND 5000),
 checksum TEXT NOT NULL CHECK(length(checksum)=64),
 payload TEXT NOT NULL CHECK(json_valid(payload) AND length(CAST(payload AS BLOB))<=1048576)
);
CREATE TABLE IF NOT EXISTS pronunciations (
 id INTEGER PRIMARY KEY, word TEXT NOT NULL, normalized_word TEXT NOT NULL,
 pronunciation TEXT NOT NULL, category TEXT NOT NULL, locale TEXT NOT NULL DEFAULT 'tr-TR',
 enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1)),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 revision INTEGER NOT NULL REFERENCES dictionary_metadata(version),
 UNIQUE(revision,locale,normalized_word)
);
CREATE TRIGGER IF NOT EXISTS publish_rules AFTER INSERT ON dictionary_metadata BEGIN
 INSERT INTO pronunciations(word,normalized_word,pronunciation,category,created_at,updated_at,revision)
 SELECT json_extract(value,'$.word'),json_extract(value,'$.normalizedWord'),json_extract(value,'$.pronunciation'),json_extract(value,'$.category'),NEW.updated_at,NEW.updated_at,NEW.version FROM json_each(NEW.payload,'$.rules');
END;
