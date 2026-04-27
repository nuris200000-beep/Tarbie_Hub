-- Таблицы Tarbie Hub (общие для всех клиентов)

CREATE TABLE IF NOT EXISTS tarbie_users (
  id BIGSERIAL PRIMARY KEY,
  login TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  roles TEXT NOT NULL,
  is_admin INTEGER NOT NULL DEFAULT 0,
  reset_code TEXT,
  reset_expires_ms BIGINT,
  avatar_path TEXT,
  status TEXT NOT NULL DEFAULT 'online',
  last_seen_ms BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS tarbie_events (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  value_tag TEXT NOT NULL,
  group_name TEXT NOT NULL,
  author_id BIGINT NOT NULL REFERENCES tarbie_users(id) ON DELETE CASCADE,
  created_at_ms BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS tarbie_notifications (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES tarbie_users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at_ms BIGINT NOT NULL,
  read INTEGER NOT NULL DEFAULT 0,
  event_id BIGINT REFERENCES tarbie_events(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_tarbie_events_created ON tarbie_events(created_at_ms DESC);
CREATE INDEX IF NOT EXISTS idx_tarbie_notifications_user ON tarbie_notifications(user_id, created_at_ms DESC);

ALTER TABLE tarbie_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarbie_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarbie_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tarbie_users_all" ON tarbie_users;
CREATE POLICY "tarbie_users_all" ON tarbie_users FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "tarbie_events_all" ON tarbie_events;
CREATE POLICY "tarbie_events_all" ON tarbie_events FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "tarbie_notifications_all" ON tarbie_notifications;
CREATE POLICY "tarbie_notifications_all" ON tarbie_notifications FOR ALL USING (true) WITH CHECK (true);

-- Начальный админ: пароль Admin123, соль supabase_seed_salt_v1 (как в приложении AuthCrypto)
INSERT INTO tarbie_users (login, display_name, password_hash, salt, roles, is_admin, status, last_seen_ms)
VALUES (
  'admin',
  'Администратор',
  '13e4353341bf4738c3a0793293aa7a9baa13f78a4617c107c6cc0c8ccb27f394',
  'supabase_seed_salt_v1',
  'deputyDirector,curator',
  1,
  'online',
  (EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT
)
ON CONFLICT (login) DO NOTHING;
