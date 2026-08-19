import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> init() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      // Fallback if .env file fails to load
    }
  }

  // Mapbox Configuration
  static String get mapboxAccessToken =>
      dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: '');
  static String get mapboxStyleUrl =>
      dotenv.get('MAPBOX_STYLE_URL', fallback: 'mapbox://styles/mapbox/dark-v11');

  static String get mapboxTileUrl {
    final token = mapboxAccessToken;
    if (token.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static String get mapboxDarkTileUrl {
    final token = mapboxAccessToken;
    if (token.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static String get mapboxSatelliteTileUrl {
    final token = mapboxAccessToken;
    if (token.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static String get mapboxOutdoorsTileUrl {
    final token = mapboxAccessToken;
    if (token.isNotEmpty) {
      return 'https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$token';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  // Firebase Configuration
  static String get firebaseApiKey =>
      dotenv.get('FIREBASE_API_KEY', fallback: '');
  static String get firebaseAuthDomain =>
      dotenv.get('FIREBASE_AUTH_DOMAIN', fallback: 'mee-parking.firebaseapp.com');
  static String get firebaseDatabaseUrl =>
      dotenv.get('FIREBASE_DATABASE_URL', fallback: 'https://mee-parking-default-rtdb.firebaseio.com');
  static String get firebaseProjectId =>
      dotenv.get('FIREBASE_PROJECT_ID', fallback: 'mee-parking');
  static String get firebaseStorageBucket =>
      dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: 'mee-parking.firebasestorage.app');
  static String get firebaseMessagingSenderId =>
      dotenv.get('FIREBASE_MESSAGING_SENDER_ID', fallback: '705882453832');
  static String get firebaseAppId =>
      dotenv.get('FIREBASE_APP_ID', fallback: '1:705882453832:web:bac93fa3a5b1485e64e57d');

  // Razorpay Configuration
  static String get razorpayKeyId =>
      dotenv.get('RAZORPAY_KEY_ID', fallback: 'rzp_live_StBUehIpeULYuL');
  static String get razorpayKeySecret =>
      dotenv.get('RAZORPAY_KEY_SECRET', fallback: 'M76UWnmNsVE7hU5QrkriZuor');

  // Cloudinary Configuration
  static String get cloudinaryCloudName =>
      dotenv.get('CLOUDINARY_CLOUD_NAME', fallback: 'dnedosgc6');
  static String get cloudinaryUploadPreset =>
      dotenv.get('CLOUDINARY_UPLOAD_PRESET', fallback: 'ml_default');
  static String get cloudinaryApiKey =>
      dotenv.get('CLOUDINARY_API_KEY', fallback: '215714759371872');
  static String get cloudinaryApiSecret =>
      dotenv.get('CLOUDINARY_API_SECRET', fallback: 'GB8D-uXCSOVavwrcbV5K2lTtCdg');
  static String get cloudinaryUrl =>
      dotenv.get('CLOUDINARY_URL', fallback: '');

  // Agora Configuration
  static String get agoraAppId =>
      dotenv.get('AGORA_APP_ID', fallback: '9cd9cd3dca32464db2f1e1f1fb02f88f');
  static String get agoraAppCertificate =>
      dotenv.get('AGORA_APP_CERTIFICATE', fallback: '181e5472fc5f49f5aa25d9b03911ee02');

  // Email Notification Service
  static String get senderEmail =>
      dotenv.get('SENDER_EMAIL', fallback: 'notifications@meeparking.com');
}
