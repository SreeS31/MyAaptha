-- Default retention is Never; owners can choose expiry per upload. Quota pressure
-- rejects new uploads and never chooses existing files for deletion.
UPDATE upload_levels SET allow_never = TRUE,
 storage_bytes = CASE WHEN id = 1 THEN 1073741824
                      WHEN storage_bytes > 107374182400 THEN 107374182400
                      ELSE storage_bytes END;
