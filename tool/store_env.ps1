param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("run", "build", "deploy-hosting", "deploy-rules")]
  [string]$Action,

  [Parameter(Mandatory = $true)]
  [string]$StoreConfigFile,

  [string]$ProjectId
)

if (!(Test-Path $StoreConfigFile)) {
  throw "Store config file not found: $StoreConfigFile"
}

switch ($Action) {
  "run" {
    flutter run -d chrome --dart-define-from-file=$StoreConfigFile
    break
  }
  "build" {
    flutter build web --dart-define-from-file=$StoreConfigFile
    break
  }
  "deploy-hosting" {
    if ([string]::IsNullOrWhiteSpace($ProjectId)) {
      throw "ProjectId is required for deploy-hosting."
    }
    flutter build web --dart-define-from-file=$StoreConfigFile
    firebase deploy --only hosting --project $ProjectId
    break
  }
  "deploy-rules" {
    if ([string]::IsNullOrWhiteSpace($ProjectId)) {
      throw "ProjectId is required for deploy-rules."
    }
    firebase deploy --only firestore:rules --project $ProjectId
    break
  }
}
