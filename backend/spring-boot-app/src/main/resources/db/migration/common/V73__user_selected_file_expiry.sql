-- Every plan supports the full user-selected expiry range and Never.
-- Existing object expiry timestamps and deleted records are preserved.
UPDATE upload_levels SET max_retention_days = 3650, allow_never = TRUE;
