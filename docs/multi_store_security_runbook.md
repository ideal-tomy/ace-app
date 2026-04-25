# Multi-Store Security Runbook

## 1) Store onboarding (new Firebase project)

1. Create a Firebase project for the store.
2. Enable:
   - Firestore
   - Firebase Authentication (Email/Password)
   - App Check (Web / reCAPTCHA v3)
3. Deploy Firestore rules from this repository:
   - `firebase deploy --only firestore:rules --project <project-id>`
4. Create one admin user in Authentication (Email/Password).
5. Add admin marker document:
   - `stores/<storeId>/admins/<adminAuthUid>`
   - Recommended fields: `email`, `createdAt`.

## 2) Environment file per store

1. Copy `firebase.web.template.json` to `firebase.web.<store>.json`.
2. Fill all Firebase keys and:
   - `APP_STORE_ID`: store identifier used in Firestore path.
   - `APP_CHECK_WEB_RECAPTCHA_SITE_KEY`: App Check site key.
3. Keep this file local only. `firebase.web.*.json` is ignored by `.gitignore`.

## 3) Run / Build / Deploy

- Local run:
  - `flutter run -d chrome --dart-define-from-file=firebase.web.<store>.json`
- Production build:
  - `flutter build web --dart-define-from-file=firebase.web.<store>.json`
- Hosting deploy:
  - `firebase deploy --only hosting --project <project-id>`

## 4) Security baseline

- Staff flow:
  - Login first, then use the app.
- Admin flow:
  - Use admin login only for management features.
- Firestore:
  - All app data is namespaced under `stores/<storeId>/...`.
  - Menu/admin write operations require admin identity.
- App Check:
  - Enabled on Web and activated by `APP_CHECK_WEB_RECAPTCHA_SITE_KEY`.

## 4.1) Required data structure per store

The following paths must exist under the same `storeId` used in runtime config:

- `stores/<storeId>/customers`
- `stores/<storeId>/checks`
- `stores/<storeId>/menus`
- `stores/<storeId>/admins/<uid>`

Notes:

- `stores/<storeId>/admins/<uid>` is the admin marker used by the app.
- Top-level collections like `admins`, `menus`, `checks`, `customers` are legacy and ignored by current repository paths/rules.

## 4.2) Permission-denied quick checks

If the app shows `[cloud_firestore/permission-denied]`:

1. Confirm Authentication has Email/Password enabled and user exists.
2. Confirm the signed-in user exists (anonymous or email user).
3. Confirm `APP_STORE_ID` matches where data is stored.
4. Confirm admin marker path is exactly:
   - `stores/<storeId>/admins/<auth uid>`
5. Re-deploy rules:
   - `firebase deploy --only firestore:rules --project <project-id>`
6. If App Check is enabled, verify reCAPTCHA site key and app registration.

## 5) Monitoring and protection

1. Budget alert:
   - Configure Google Cloud Billing budget + alert email per project.
2. Usage alert:
   - Add alerting on Firestore document read/write spikes.
3. Auth alert:
   - Add alerting on abnormal sign-in failures.

## 6) Backup and restore drill

1. Enable scheduled Firestore export to Cloud Storage.
2. Define retention period (for example 30-90 days).
3. Run restore drill monthly on a staging project.
4. Keep a short recovery checklist with owners and RTO/RPO targets.
