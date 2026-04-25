# Flutter Web をビルドしてから Firebase Hosting に上げる（再ビルド忘れ防止）
# 使い方: プロジェクト直下で .\deploy_hosting.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "== flutter build web ==" -ForegroundColor Cyan
flutter build web `
  --dart-define=FIREBASE_API_KEY="AIzaSyCBeZ6VOM0XvrytA5JvKI2-w6nldHw1WEg" `
  --dart-define=FIREBASE_APP_ID="1:1008524311093:web:2b6b43237d1c265d748f7c" `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="1008524311093" `
  --dart-define=FIREBASE_PROJECT_ID="aca-app-98fbc" `
  --dart-define=FIREBASE_AUTH_DOMAIN="aca-app-98fbc.firebaseapp.com" `
  --dart-define=FIREBASE_STORAGE_BUCKET="aca-app-98fbc.firebasestorage.app"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`n== firebase deploy (hosting) ==" -ForegroundColor Cyan
firebase deploy --only hosting
exit $LASTEXITCODE
