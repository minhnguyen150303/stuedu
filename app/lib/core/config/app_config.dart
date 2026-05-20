import 'dart:io';

class AppConfig {
  static const String _baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_baseUrl.isNotEmpty) {
      return _baseUrl;
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }

    if (Platform.isIOS) {
      return 'http://127.0.0.1:5000/api';
    }

    return 'http://localhost:5000/api';
  }
}
