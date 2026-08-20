import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/security_helper.dart';

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
      dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: SecurityHelper.decryptSecret('3d2e6b3a290b630223212e3c14037106650540521a742d3c3e0f61121e7f72163a322a066179047f200b31113e2263287a14373b0707283b75574b572308703d627420057b14363c3d262a39631e7e457c20770866332a78283e281d2016370853057d41'));
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
      dotenv.get('FIREBASE_API_KEY', fallback: SecurityHelper.decryptSecret('0c0c3f3e0338137f2d77006e6228160f5f5c5b471f722e2a0031227b33283f3330310f2e064667'));
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
      dotenv.get('RAZORPAY_KEY_ID', fallback: SecurityHelper.decryptSecret('3f3f35003c28242e161d331d06202b164255677a143009'));
  static String get razorpayKeySecret =>
      dotenv.get('RAZORPAY_KEY_SECRET', fallback: SecurityHelper.decryptSecret('0072730a072f3f053a1802683b10760e405b405f17302a2d'));

  // Cloudinary Configuration
  static String get cloudinaryCloudName =>
      dotenv.get('CLOUDINARY_CLOUD_NAME', fallback: 'dnedosgc6');
  static String get cloudinaryUploadPreset =>
      dotenv.get('CLOUDINARY_UPLOAD_PRESET', fallback: 'ml_default');
  static String get cloudinaryApiKey =>
      dotenv.get('CLOUDINARY_API_KEY', fallback: SecurityHelper.decryptSecret('7f7470686175657e707d706e6b7271'));
  static String get cloudinaryApiSecret =>
      dotenv.get('CLOUDINARY_API_SECRET', fallback: SecurityHelper.decryptSecret('0a077d1b7d340a081a01113e2532313c5066077d7f29112b132535'));
  static String get cloudinaryUrl =>
      dotenv.get('CLOUDINARY_URL', fallback: '');

  // Agora Configuration
  static String get agoraAppId =>
      dotenv.get('AGORA_APP_ID', fallback: SecurityHelper.decryptSecret('742621663325612f2a2f746d6773773b500254072874236e362362792f767f39'));
  static String get agoraAppCertificate =>
      dotenv.get('AGORA_APP_CERTIFICATE', fallback: SecurityHelper.decryptSecret('7c7d743a657565792f2d7239677c256a53510003297c276f6378637a2c2b776d'));

  // Email Notification Service
  static String get senderEmail =>
      dotenv.get('SENDER_EMAIL', fallback: 'notifications@meeparking.com');
}
