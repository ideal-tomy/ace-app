param(
  [Parameter(Mandatory = $true)]
  [string]$BuildIndexHtml,

  [Parameter(Mandatory = $true)]
  [string]$StoreConfigFile
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $BuildIndexHtml)) {
  throw "index.html not found: $BuildIndexHtml"
}
if (!(Test-Path $StoreConfigFile)) {
  throw "Store config not found: $StoreConfigFile"
}

$config = Get-Content $StoreConfigFile -Raw | ConvertFrom-Json
$html = Get-Content $BuildIndexHtml -Raw -Encoding UTF8

$runtimeScript = @"
  <script>
    (function () {
      window.__ACE_FIREBASE_CONFIG__ = {
        FIREBASE_API_KEY: "$($config.FIREBASE_API_KEY)",
        FIREBASE_APP_ID: "$($config.FIREBASE_APP_ID)",
        FIREBASE_MESSAGING_SENDER_ID: "$($config.FIREBASE_MESSAGING_SENDER_ID)",
        FIREBASE_PROJECT_ID: "$($config.FIREBASE_PROJECT_ID)",
        FIREBASE_AUTH_DOMAIN: "$($config.FIREBASE_AUTH_DOMAIN)",
        FIREBASE_STORAGE_BUCKET: "$($config.FIREBASE_STORAGE_BUCKET)"
      };
      if ("serviceWorker" in navigator) {
        navigator.serviceWorker.getRegistrations().then(function (regs) {
          regs.forEach(function (reg) { reg.unregister(); });
        });
      }
      if ("caches" in window) {
        caches.keys().then(function (keys) {
          keys.forEach(function (key) { caches.delete(key); });
        });
      }
    })();
  </script>
"@

if ($html -notmatch '__ACE_FIREBASE_CONFIG__') {
  $html = $html.Replace(
    '  <script src="flutter_bootstrap.js" async></script>',
    "$runtimeScript`n  <script src=`"flutter_bootstrap.js`" async></script>"
  )
}

Set-Content -Path $BuildIndexHtml -Value $html -Encoding UTF8 -NoNewline
Write-Host "Injected runtime Firebase config into $BuildIndexHtml"
