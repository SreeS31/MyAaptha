INSERT INTO people (full_name, email)
SELECT 'Ava Patel', 'ava@myaaptha.ai'
WHERE NOT EXISTS (SELECT 1 FROM people WHERE email = 'ava@myaaptha.ai');

INSERT INTO circles (name, description)
SELECT 'Engineering', 'Core platform collaboration circle'
WHERE NOT EXISTS (SELECT 1 FROM circles WHERE name = 'Engineering');

INSERT INTO relationships (type)
SELECT 'friend'
WHERE NOT EXISTS (SELECT 1 FROM relationships WHERE type = 'friend');

INSERT INTO permissions (name, description)
SELECT 'admin', 'Full platform access'
WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE name = 'admin');

INSERT INTO projects (name, description, status)
SELECT 'MyAaptha Platform', 'Initial platform delivery track', 'Active'
WHERE NOT EXISTS (SELECT 1 FROM projects WHERE name = 'MyAaptha Platform');

INSERT INTO tasks (title, details, status, project_id, milestone_id)
SELECT 'Kickoff architecture review', 'Review baseline architecture and service boundaries', 'Todo', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM tasks WHERE title = 'Kickoff architecture review');

INSERT INTO milestones (name, description, status, project_id, due_date, blocked_reason)
SELECT 'Phase 1 Foundation', 'Complete core domain and dashboard API integration', 'In Progress', NULL, DATE '2026-08-31', NULL
WHERE NOT EXISTS (SELECT 1 FROM milestones WHERE name = 'Phase 1 Foundation');
