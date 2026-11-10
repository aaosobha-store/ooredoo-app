class OoredooConfig {
  static const baseUrl = 'https://apps.ooredoo.dz/carrier-prod/api';
  static const appId = 'ussd_app';

  static const stormCode = '*580#';
  static const bundleCode = '*585#';

  /// Ooredoo closes an idle USSD session after about a minute.
  static const sessionSeconds = 60;
}
