-- Заявки социальной помощи (студент → соцпед / замдиректор).

CREATE TABLE IF NOT EXISTS tarbie_social_requests (
  id BIGSERIAL PRIMARY KEY,
  author_id BIGINT NOT NULL REFERENCES tarbie_users(id) ON DELETE CASCADE,
  author_name TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  staff_reply TEXT,
  created_at_ms BIGINT NOT NULL,
  updated_at_ms BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tarbie_social_requests_author ON tarbie_social_requests(author_id);
CREATE INDEX IF NOT EXISTS idx_tarbie_social_requests_created ON tarbie_social_requests(created_at_ms DESC);

ALTER TABLE tarbie_social_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tarbie_social_requests_all" ON tarbie_social_requests;
CREATE POLICY "tarbie_social_requests_all" ON tarbie_social_requests FOR ALL USING (true) WITH CHECK (true);
