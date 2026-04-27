-- Группы (справочник), почта и привязка пользователя к группе.

CREATE TABLE IF NOT EXISTS tarbie_groups (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

ALTER TABLE tarbie_users ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE tarbie_users ADD COLUMN IF NOT EXISTS group_id BIGINT REFERENCES tarbie_groups(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS tarbie_users_email_unique
  ON tarbie_users (lower(email))
  WHERE email IS NOT NULL AND trim(email) <> '';

ALTER TABLE tarbie_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tarbie_groups_all" ON tarbie_groups;
CREATE POLICY "tarbie_groups_all" ON tarbie_groups FOR ALL USING (true) WITH CHECK (true);

-- Админу из миграции 001 — служебная почта (можно сменить вручную)
UPDATE tarbie_users
SET email = 'admin@tarbie.local'
WHERE login = 'admin' AND (email IS NULL OR trim(email) = '');
