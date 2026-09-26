import 'package:shared_preferences/shared_preferences.dart';

class AssistantConfig {
  const AssistantConfig._();

  static const String proxyUrl = String.fromEnvironment(
    'ASSISTANT_PROXY_URL',
    defaultValue: 'http://localhost:8787',
  );

  static const String appToken = String.fromEnvironment('ASSISTANT_APP_TOKEN');

  static const String model = String.fromEnvironment(
    'ASSISTANT_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );

  static const String _kProxyUrl = 'assistant.proxy_url';
  static const String _kAppToken = 'assistant.app_token';
  static const String _kModel = 'assistant.model';

  static String proxyUrlOf(SharedPreferences prefs) {
    final stored = prefs.getString(_kProxyUrl)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return proxyUrl;
  }

  static String appTokenOf(SharedPreferences prefs) {
    final stored = prefs.getString(_kAppToken)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return appToken;
  }

  static String modelOf(SharedPreferences prefs) {
    final stored = prefs.getString(_kModel)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return model;
  }

  static void saveSettings(
    SharedPreferences prefs, {
    required String proxyUrl,
    required String appToken,
    required String model,
  }) {
    _put(prefs, _kProxyUrl, proxyUrl);
    _put(prefs, _kAppToken, appToken);
    _put(prefs, _kModel, model);
  }

  static void _put(SharedPreferences prefs, String key, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      prefs.remove(key);
    } else {
      prefs.setString(key, trimmed);
    }
  }

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
