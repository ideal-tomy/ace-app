class AppConfig {
  static const storeId = String.fromEnvironment(
    'APP_STORE_ID',
    defaultValue: 'default-store',
  );

  static const adminRoleClaim = String.fromEnvironment(
    'ADMIN_ROLE_CLAIM',
    defaultValue: 'isAdmin',
  );

  static const moduleRolesClaim = String.fromEnvironment(
    'MODULE_ROLES_CLAIM',
    defaultValue: 'moduleRoles',
  );

  static const moduleRolesField = String.fromEnvironment(
    'MODULE_ROLES_FIELD',
    defaultValue: 'moduleRoles',
  );

  static const appCheckWebRecaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );
}
