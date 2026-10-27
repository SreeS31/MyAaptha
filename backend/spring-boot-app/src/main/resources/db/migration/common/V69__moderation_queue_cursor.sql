-- Match the status-filtered keyset query without sorting the entire status queue.
CREATE INDEX idx_abuse_status_id ON abuse_reports(status, id DESC);
