class AppConfig {
  static const storeId = String.fromEnvironment(
    'APP_STORE_ID',
    defaultValue: 'default-store',
  );

  static const adminRoleClaim = String.fromEnvironment(
    'ADMIN_ROLE_CLAIM',
    defaultValue: 'isAdmin',
  );

  static const appCheckWebRecaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );
}
