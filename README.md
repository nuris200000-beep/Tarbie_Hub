# Tarbie Hub (`tarbie_hub`)

Flutter-приложение колледжа: лента, мероприятия, профиль, Supabase в облачном режиме.

## Публикация веб-версии на https://tarbiehub.us

### Вариант A — вручную с компьютера

1. `flutter config --enable-web`
2. `.\scripts\build_web.ps1` или `flutter build web --release`
3. [Cloudflare Dashboard](https://dash.cloudflare.com/) → **Workers & Pages** → **Create** → **Pages** → **Upload assets** → загрузите **всё содержимое** папки `build/web`.

### Вариант B — GitHub Actions → Cloudflare Pages (автособка при push)

1. В Cloudflare: **Workers & Pages** → **Create** → **Pages** → создайте проект с именем **`tarbiehub`** (без первого деплоя можно «Direct Upload» пустышкой или сразу после первого успешного запуска Actions проект появится сам — см. [документацию](https://developers.cloudflare.com/pages/get-started/guide/)). Надёжнее один раз создать пустой проект **tarbiehub** в интерфейсе.
2. Возьмите **Account ID**: главная Cloudflare → справа внизу «Account ID», или **Workers & Pages** → любой проект → справа.
3. Создайте **API Token**: **My Profile** → **API Tokens** → **Create Token** → шаблон **Edit Cloudflare Workers** или свой с правами **Account → Cloudflare Pages → Edit** (и при необходимости **Read** на аккаунт).
4. На GitHub в репозитории: **Settings** → **Secrets and variables** → **Actions** → добавьте:
   - `CLOUDFLARE_API_TOKEN` — токен;
   - `CLOUDFLARE_ACCOUNT_ID` — ID аккаунта.
5. Закоммитьте и запушьте в ветку **`main`** или **`master`** — запустится workflow [`.github/workflows/deploy-cloudflare-pages.yml`](.github/workflows/deploy-cloudflare-pages.yml). При необходимости: вкладка **Actions** → **Deploy Cloudflare Pages** → **Run workflow**.
6. Если имя проекта в Cloudflare не **`tarbiehub`**, отредактируйте поле `projectName` в этом workflow.
7. В проекте Pages → **Custom domains** привяжите **`tarbiehub.us`** (и при желании `www`).

**Если в Actions ошибка `401` / `Authentication error` при шаге Publish:** токен не подходит или скопирован с лишним пробелом. Удалите секрет **`CLOUDFLARE_API_TOKEN`** и создайте заново в Cloudflare → **API Tokens** → **Create Custom Token**:
- **Permissions:** **Account** → **Cloudflare Pages** → **Edit**; добавьте **Account** → **Workers Scripts** → **Read** (часто нужно для запроса проекта).
- **Account Resources:** ваш аккаунт (тот же **Account ID**, что в секрете GitHub).
Либо возьмите готовый шаблон **Edit Cloudflare Workers**. Затем снова **Actions → Re-run failed jobs**.

Файл **`web/_redirects`** попадает в сборку (`/* → index.html` для SPA).

Ключи Supabase: [`lib/config/tarbie_cloud_config.dart`](lib/config/tarbie_cloud_config.dart). База и почта: [`supabase/README.md`](supabase/README.md).

## Getting Started (Flutter)

- [Flutter install](https://docs.flutter.dev/get-started/install)
- Локально в браузере: `flutter run -d chrome`
