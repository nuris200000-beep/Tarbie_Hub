# Общая база для всех установок приложения

## После регистрации в Supabase — по шагам

1. **Создайте проект** (если ещё не создали): Dashboard → **New project** → дождитесь статуса «Healthy».
2. **Таблицы:** слева **SQL Editor** → **New query** → выполните по очереди **`001_tarbie_schema.sql`**, затем **`004_user_email_group_groups.sql`** (группы, email, привязка к группе).
3. **Аватары:** слева **Storage** → **New bucket** → имя **`avatars`** → включите **Public bucket**. Затем в **SQL Editor** выполните `migrations/002_storage_avatars_policies.sql` (политики для anon + upsert). Если фото уже даёт **403 / row-level security** — выполните **тот же файл ещё раз** (скрипт идемпотентный: пересоздаёт политики).
4. **Ключи для приложения:** слева **Project Settings** (шестерёнка) → **Data API** / раздел **API** → скопируйте:
   - **Project URL** (например `https://abcdefgh.supabase.co`),
   - **anon public** key (длинная строка, начинается с `eyJ...`).
5. **Вставьте в код:** откройте `lib/config/tarbie_cloud_config.dart` и вставьте URL и ключ в `embeddedSupabaseUrl` и `embeddedSupabaseAnonKey` (в кавычках, как строки).
6. **Сброс пароля по email:** приложение вызывает Edge Function **`send-reset-code`**. Установите [Supabase CLI](https://supabase.com/docs/guides/cli), в корне проекта выполните `supabase link`, затем:
   - зарегистрируйте [Resend](https://resend.com), создайте API key;
   - в Dashboard проекта: **Edge Functions → Secrets** добавьте `RESEND_API_KEY` (и при желании `MAIL_FROM`, например `Имя <noreply@ваш-домен.com>`);
   - задеплойте функцию: `supabase functions deploy send-reset-code`.
   Файл функции: `supabase/functions/send-reset-code/index.ts`.
7. **Запустите приложение заново** (`flutter run` или сборка). Войдите как **admin** / **Admin123**, в админ-панели на вкладке **«Группы»** добавьте хотя бы одну группу — без этого регистрация студентов недоступна.

Чтобы **любой**, кто скачал приложение, сразу работал с одной удалённой базой (телефон, ПК и т.д.):

## 1. Один проект Supabase

Создайте проект на [supabase.com](https://supabase.com).

## 2. Схема и админ

В **SQL Editor** выполните `migrations/001_tarbie_schema.sql`, затем `004_user_email_group_groups.sql`.

Создайте публичный bucket **avatars** в Storage (политики на чтение/загрузку для `anon` — см. документацию Supabase).

## 3. Вшить ключи в приложение

Откройте `lib/config/tarbie_cloud_config.dart` и заполните **один раз**:

- `embeddedSupabaseUrl` — Project URL  
- `embeddedSupabaseAnonKey` — anon public key  

После этого **пересоберите** APK/EXE/IPA и раздавайте сборку: все клиенты пойдут в этот проект, без ввода настроек внутри приложения.

**Альтернатива:** не хранить ключи в репозитории, а передавать при сборке CI:

```text
flutter build apk --dart-define=TARBIE_SUPABASE_URL=https://....supabase.co --dart-define=TARBIE_SUPABASE_ANON=eyJ...
```

Если URL и ключ **не** заданы (ни в файле, ни через define), приложение использует только **локальную** SQLite на устройстве.

Первый вход в облаке после SQL: **admin** / **Admin123** (если не меняли сид в миграции).

> Для учебного проекта в SQL включены открытые RLS. Для продакшена ужесточьте политики.
