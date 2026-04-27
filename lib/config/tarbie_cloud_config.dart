/// Общая база для **всех**, кто установил приложение (телефон, ПК и т.д.).
///
/// 1. Создайте один проект на [supabase.com](https://supabase.com).
/// 2. Выполните SQL из `supabase/migrations/001_tarbie_schema.sql`, создайте bucket `avatars`.
/// 3. Вставьте ниже **Project URL** и **anon public** key (Settings → API).
///
/// Либо при сборке без правки файла:
/// `flutter build apk --dart-define=TARBIE_SUPABASE_URL=https://xxx.supabase.co --dart-define=TARBIE_SUPABASE_ANON=eyJ...`
///
/// Если URL и ключ пустые — используется только локальная SQLite на устройстве.
class TarbieCloudConfig {
  TarbieCloudConfig._();

  static const String _fromEnvUrl = String.fromEnvironment('TARBIE_SUPABASE_URL', defaultValue: '');
  static const String _fromEnvAnon = String.fromEnvironment('TARBIE_SUPABASE_ANON', defaultValue: '');

  /// Для готовых сборок — значения из [Dashboard](https://supabase.com/dashboard) → проект → **Settings → API**.
  ///
  /// **Project URL** — только origin: `https://<reference_id>.supabase.co` без `/rest/v1/`
  /// (путь `/rest/v1/` к PostgREST добавляет SDK сам).
  ///
  /// **Ключ для клиента:** на вкладке **«Legacy anon, service_role API keys»** скопируйте **`anon`
  /// `public`** (длинный JWT, начинается с `eyJ`). Его ожидает `supabase_flutter`.
  /// Ключ **Publishable** (`sb_publishable_…`) на первой вкладке — другой формат; не подставляйте его
  /// вместо `anon`, пока не обновите клиент по документации Supabase для новых ключей.
  static const String embeddedSupabaseUrl = 'https://lqldgezuaujycdiebvwt.supabase.co';
  static const String embeddedSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxbGRnZXp1YXVqeWNkaWVidnd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMDUyMzIsImV4cCI6MjA5MjU4MTIzMn0.-9oOpdaPMTYrHuGINaJ0EMyjLXYctYb7SJCaXtBjV5o';

  static String get supabaseUrl {
    final u = _fromEnvUrl.trim();
    if (u.isNotEmpty) return u;
    return embeddedSupabaseUrl.trim();
  }

  static String get supabaseAnonKey {
    final k = _fromEnvAnon.trim();
    if (k.isNotEmpty) return k;
    return embeddedSupabaseAnonKey.trim();
  }

  static bool get isCloudEnabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
