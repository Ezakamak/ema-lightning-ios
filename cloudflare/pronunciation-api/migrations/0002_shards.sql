-- Additive: v1 snapshots and triggers remain untouched.
CREATE TABLE dictionary_chunks (
 hash TEXT PRIMARY KEY CHECK(length(hash)=64),
 payload TEXT NOT NULL CHECK(json_valid(payload) AND length(CAST(payload AS BLOB))<=262144)
);
CREATE TABLE dictionary_releases (
 version INTEGER PRIMARY KEY CHECK(version>0),
 manifest TEXT NOT NULL CHECK(json_valid(manifest)),
 created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE TABLE dictionary_channels (
 channel TEXT PRIMARY KEY CHECK(channel IN ('staging','stable')),
 version INTEGER NOT NULL REFERENCES dictionary_releases(version)
);
CREATE TRIGGER release_complete BEFORE INSERT ON dictionary_releases BEGIN
 SELECT CASE WHEN json_extract(NEW.manifest,'$.version')!=NEW.version
 OR json_extract(NEW.manifest,'$.schemaVersion')!=2
 OR json_extract(NEW.manifest,'$.ruleCount') NOT BETWEEN 1 AND 100000
 OR NOT EXISTS(SELECT 1 FROM json_each(NEW.manifest,'$.chunks'))
 OR EXISTS(SELECT 1 FROM json_each(NEW.manifest,'$.chunks') c
 LEFT JOIN dictionary_chunks d ON d.hash=json_extract(c.value,'$.hash')
 WHERE d.hash IS NULL OR length(CAST(d.payload AS BLOB))!=json_extract(c.value,'$.bytes'))
 THEN RAISE(ABORT,'incomplete release') END;
END;
-- Published content is immutable; rollback changes the channel pointer only.
CREATE TRIGGER immutable_chunk BEFORE UPDATE ON dictionary_chunks BEGIN SELECT RAISE(ABORT,'immutable'); END;
CREATE TRIGGER immutable_release BEFORE UPDATE ON dictionary_releases BEGIN SELECT RAISE(ABORT,'immutable'); END;
