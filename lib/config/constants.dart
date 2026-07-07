import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'CAUCE Stream';

  static String get driveApiKey => _get('DRIVE_API_KEY');
  static String get driveFolderId => _get('DRIVE_FOLDER_ID');

  static const String driveBaseUrl = 'https://www.googleapis.com/drive/v3';
  static const String driveDownloadUrl = 'https://www.googleapis.com/drive/v3/files';


  static String _get(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('$key no está definida en el archivo .env');
    }
    return value;
  }
}
