CREATE TABLE upload_levels (
 id INTEGER PRIMARY KEY CHECK (id BETWEEN 1 AND 5),
 name VARCHAR(50) NOT NULL,
 storage_bytes BIGINT NOT NULL CHECK (storage_bytes >= 0),
 upload_bytes BIGINT NOT NULL CHECK (upload_bytes BETWEEN 1 AND 26214400),
 max_retention_days INTEGER NOT NULL CHECK (max_retention_days BETWEEN 1 AND 36500),
 allow_never BOOLEAN NOT NULL
);
INSERT INTO upload_levels VALUES (1, 'Free', 1073741824, 26214400, 36500, TRUE);
INSERT INTO upload_levels VALUES (2, 'Premium', 5368709120, 26214400, 36500, TRUE);
ALTER TABLE users ADD COLUMN upload_level_id INTEGER NOT NULL DEFAULT 1 REFERENCES upload_levels(id);
