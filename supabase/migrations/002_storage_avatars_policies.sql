-- Политики Storage для bucket `avatars` (загрузка фото с anon-ключом приложения).
-- Выполните в SQL Editor, если фото даёт 403 / "new row violates row-level security policy".
--
-- Важно:
-- 1) Bucket в Dashboard должен называться `avatars` и быть **Public**.
-- 2) `uploadBinary(..., upsert: true)` требует политики SELECT + INSERT + UPDATE (не только INSERT).

-- Снимаем все варианты имён (в т.ч. старая опечатка avatars_delete_own в DROP)
DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert_anon" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update_anon" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_anon" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;

-- TO public — все роли, включая anon (JWT с ролью anon из приложения).
-- Условие по bucket: имя `avatars` или id совпадает со строкой в storage.buckets.
CREATE POLICY "avatars_select_public"
ON storage.objects FOR SELECT
TO public
USING (
  bucket_id = 'avatars'
  OR bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'avatars')
);

CREATE POLICY "avatars_insert_anon"
ON storage.objects FOR INSERT
TO public
WITH CHECK (
  bucket_id = 'avatars'
  OR bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'avatars')
);

CREATE POLICY "avatars_update_anon"
ON storage.objects FOR UPDATE
TO public
USING (
  bucket_id = 'avatars'
  OR bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'avatars')
)
WITH CHECK (
  bucket_id = 'avatars'
  OR bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'avatars')
);

CREATE POLICY "avatars_delete_anon"
ON storage.objects FOR DELETE
TO public
USING (
  bucket_id = 'avatars'
  OR bucket_id IN (SELECT id FROM storage.buckets WHERE name = 'avatars')
);

-- Чтение storage.buckets для подзапроса (если на buckets включён RLS без SELECT для anon)
DROP POLICY IF EXISTS "avatars_buckets_select_anon" ON storage.buckets;
CREATE POLICY "avatars_buckets_select_anon"
ON storage.buckets FOR SELECT
TO public
USING (name = 'avatars');
