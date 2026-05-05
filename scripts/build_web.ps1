# Сборка Flutter Web для публикации (Cloudflare Pages, любой статический хостинг).
# Результат: папка build/web → загрузите её содержимое на тариф Pages или через Wrangler.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
flutter build web --release
Write-Host 'Готово: загрузите содержимое build/web на tarbiehub.us (Cloudflare Pages или см. README).' -ForegroundColor Green
