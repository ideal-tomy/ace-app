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
- `stores/<storeId>/admins/<uid>` (admin marker)

Top-level collections like `customers`, `checks`, `menus`, `admins` are legacy and not used by current security rules.

## Authentication and permission model

- Signed-in users only:
  - Login is required before using the app.
  - Regular users can perform daily operations (visit register, ordering, browsing records).
  - Admin operations (menu updates, finalization, protected edits) still require admin marker.
- Admin users:
  - Must exist in Auth (Email/Password or other provider)
  - Must have admin marker document at `stores/<storeId>/admins/<uid>`

## Troubleshooting permission-denied

1. Ensure Authentication has `Email/Password` enabled and the user can sign in.
2. Ensure the app runs with the expected `APP_STORE_ID`.
3. Ensure admin marker path is exactly `stores/<storeId>/admins/<uid>`.
4. Ensure Firestore rules were deployed:
   - `firebase deploy --only firestore:rules --project <project-id>`
5. If using App Check, ensure correct site key is configured.
