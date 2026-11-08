-- Active files are retained until their owner deletes them. Quota pressure
-- rejects new uploads and never chooses existing files for deletion.
UPDATE upload_levels SET allow_never = TRUE,
 storage_bytes = CASE WHEN id = 1 THEN 1073741824
                      WHEN storage_bytes > 107374182400 THEN 107374182400
                      ELSE storage_bytes END;

-- Preserve explicit story lifetimes and every already-deleted record.
UPDATE media_assets SET expires_at = NULL
 WHERE deleted_at IS NULL AND expires_at IS NOT NULL
 AND storage_key NOT IN (SELECT media_key FROM social_stories);
