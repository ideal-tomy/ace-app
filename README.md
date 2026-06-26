# ace_app

Firebase + Flutter Web based accounting helper app.

## Required environment values

Use `--dart-define-from-file` and provide these keys:

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`
- `APP_STORE_ID` (example: `default-store`)
- `ADMIN_ROLE_CLAIM` (default: `isAdmin`)
- `APP_CHECK_WEB_RECAPTCHA_SITE_KEY` (optional while developing)

Template file:

- `firebase.web.template.json`

## Run locally

```powershell
flutter run -d chrome --dart-define-from-file=firebase.web.dev.json
```

## Data path rule

All application data must exist under:

- `stores/<storeId>/customers`
- `stores/<storeId>/checks`
- `stores/<storeId>/menus`
- `stores/<storeId>/users/<uid>` (optional module roles)
- `stores/<storeId>/accounting_entries`
- `stores/<storeId>/expense_entries`

Legacy top-level `admins/{email}` documents are optional and kept for backward compatibility.

## Authentication and permission model

- Login is required before using the app (Firebase Email/Password).
- **Email-authenticated users are treated as store admins** and can:
  - register visits, take orders, finalize checkout
  - edit menus and manage user permissions
  - access expense admin features
- Visit registration asks for business mode (event vs normal) on each registration; there is no global mode selector.
- Optional fine-grained roles via `stores/<storeId>/users/<uid>.moduleRoles` remain supported for legacy setups without email addresses.

## Business modes

- **Event (`event`)**: order-based billing; all menu items are available; no time charge.
- **Normal (`normal`)**: time-based billing; menu shows exception drinks only (tequila, champagne, etc.); food and merchandise can be added manually.

## Troubleshooting permission-denied

1. Ensure Authentication has `Email/Password` enabled and the user can sign in with an email address.
2. Ensure the app runs with the expected `APP_STORE_ID`.
3. Ensure Firestore rules were deployed:
   - `firebase deploy --only firestore:rules --project <project-id>`
4. If using App Check, ensure correct site key is configured.
5. Disable or remove Firebase Auth accounts for users who should no longer have access.
