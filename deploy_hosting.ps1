# Flutter Web をビルドしてから Firebase Hosting に上げる（再ビルド忘れ防止）
# 使い方: プロジェクト直下で .\deploy_hosting.ps1
#
# 注意: flutter build web だけだと Firebase 設定が入らず「初期化に失敗」になります。
# 必ずこのスクリプトか --dart-define-from-file 付きでビルドしてください。

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$StoreConfigFile = Join-Path $PSScriptRoot "firebase.web.default-store.json"
if (!(Test-Path $StoreConfigFile)) {
  throw "Store config not found: $StoreConfigFile"
}

Write-Host "== flutter build web ==" -ForegroundColor Cyan
flutter build web --dart-define-from-file=$StoreConfigFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$BuildIndexHtml = Join-Path $PSScriptRoot "build\web\index.html"
& (Join-Path $PSScriptRoot "tool\inject_hosting_runtime_config.ps1") `
  -BuildIndexHtml $BuildIndexHtml `
  -StoreConfigFile $StoreConfigFile

Copy-Item `
  (Join-Path $PSScriptRoot "tool\hosting_service_worker.js") `
  (Join-Path $PSScriptRoot "build\web\flutter_service_worker.js") `
  -Force

Write-Host "`n== firebase deploy (hosting) ==" -ForegroundColor Cyan
firebase deploy --only hosting
exit $LASTEXITCODE
