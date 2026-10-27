CREATE TABLE app_settings (
  user_id BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  discoverable BOOLEAN NOT NULL DEFAULT FALSE,
  share_interests BOOLEAN NOT NULL DEFAULT FALSE,
  settings_json TEXT NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX app_settings_discoverable_idx ON app_settings(discoverable, user_id);
