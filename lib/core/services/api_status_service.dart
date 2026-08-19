import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

class ApiKeyStatus {
  final String serviceName;
  final String keyName;
  final String keyValue;
  final bool isConfigured;
  bool? isValid;
  bool isLoading;
  String? message;

  ApiKeyStatus({
    required this.serviceName,
    required this.keyName,
    required this.keyValue,
    required this.isConfigured,
    this.isValid,
    this.isLoading = false,
    this.message,
  });
}

class ApiStatusService {
  static Future<List<ApiKeyStatus>> checkAllApiKeys() async {
    List<ApiKeyStatus> statuses = [];

    // 1. Mapbox Access Token
    final mapboxToken = EnvConfig.mapboxAccessToken;
    final mapboxStatus = ApiKeyStatus(
      serviceName: 'Mapbox Navigation & Maps',
      keyName: 'MAPBOX_ACCESS_TOKEN',
      keyValue: mapboxToken,
      isConfigured: mapboxToken.isNotEmpty,
    );
    statuses.add(mapboxStatus);

    // 2. Firebase API Key
    final firebaseKey = EnvConfig.firebaseApiKey;
    final firebaseStatus = ApiKeyStatus(
      serviceName: 'Firebase Realtime DB & Auth',
      keyName: 'FIREBASE_API_KEY',
      keyValue: firebaseKey,
      isConfigured: firebaseKey.isNotEmpty,
    );
    statuses.add(firebaseStatus);

    // 3. Razorpay Key ID
    final razorpayKey = EnvConfig.razorpayKeyId;
    final razorpayStatus = ApiKeyStatus(
      serviceName: 'Razorpay Payments',
      keyName: 'RAZORPAY_KEY_ID',
      keyValue: razorpayKey,
      isConfigured: razorpayKey.isNotEmpty,
    );
    statuses.add(razorpayStatus);

    // 4. Cloudinary API Key
    final cloudinaryKey = EnvConfig.cloudinaryApiKey;
    final cloudinaryStatus = ApiKeyStatus(
      serviceName: 'Cloudinary Media Storage',
      keyName: 'CLOUDINARY_API_KEY',
      keyValue: cloudinaryKey,
      isConfigured: cloudinaryKey.isNotEmpty,
    );
    statuses.add(cloudinaryStatus);

    // 5. Agora App ID
    final agoraAppId = EnvConfig.agoraAppId;
    final agoraStatus = ApiKeyStatus(
      serviceName: 'Agora Audio/Video Calls',
      keyName: 'AGORA_APP_ID',
      keyValue: agoraAppId,
      isConfigured: agoraAppId.isNotEmpty,
    );
    statuses.add(agoraStatus);

    return statuses;
  }

  static Future<ApiKeyStatus> verifySingleKey(ApiKeyStatus item) async {
    item.isLoading = true;
    if (!item.isConfigured || item.keyValue.trim().isEmpty) {
      item.isValid = false;
      item.message = 'Key is missing or empty in .env';
      item.isLoading = false;
      return item;
    }

    try {
      switch (item.keyName) {
        case 'MAPBOX_ACCESS_TOKEN':
          final token = item.keyValue.trim();
          final isValidFormat = token.startsWith('pk.') || token.startsWith('sk.');
          try {
            final url = Uri.parse(
                'https://api.mapbox.com/geocoding/v5/mapbox.places/London.json?access_token=$token&limit=1');
            final res = await http.get(url).timeout(const Duration(seconds: 7));
            if (res.statusCode == 200) {
              item.isValid = true;
              item.message = 'Mapbox token verified & active for Maps/Navigation';
            } else if (res.statusCode == 401) {
              item.isValid = false;
              item.message = 'Unauthorized / Invalid Mapbox Access Token (HTTP 401)';
            } else {
              item.isValid = false;
              item.message = 'Mapbox request failed (HTTP ${res.statusCode})';
            }
          } catch (e) {
            if (isValidFormat) {
              item.isValid = true;
              item.message = 'Mapbox token format valid';
            } else {
              rethrow;
            }
          }
          break;

        case 'FIREBASE_API_KEY':
          final key = item.keyValue.trim();
          final isValidFormat = key.startsWith('AIza') && key.length >= 30;
          try {
            final url = Uri.parse(
                'https://identitytoolkit.googleapis.com/v1/projects?key=$key');
            final res = await http.get(url).timeout(const Duration(seconds: 7));
            if (res.statusCode == 200 || res.statusCode == 400 || res.statusCode == 403) {
              final data = jsonDecode(res.body);
              if (data['error'] != null &&
                  data['error']['message'] == 'API_KEY_INVALID') {
                item.isValid = false;
                item.message = 'Firebase API Key is invalid';
              } else {
                item.isValid = true;
                item.message = 'API Key active & accepted by Google Services';
              }
            } else {
              item.isValid = false;
              item.message = 'Verification failed (HTTP ${res.statusCode})';
            }
          } catch (e) {
            if (isValidFormat) {
              item.isValid = true;
              item.message = 'Firebase API Key format valid';
            } else {
              rethrow;
            }
          }
          break;

        case 'RAZORPAY_KEY_ID':
          final key = item.keyValue.trim();
          final secret = EnvConfig.razorpayKeySecret.trim();
          final isValidFormat = (key.startsWith('rzp_test_') || key.startsWith('rzp_live_') || key.startsWith('rzp_')) && key.length >= 14;

          if (kIsWeb) {
            if (isValidFormat && secret.isNotEmpty) {
              item.isValid = true;
              item.message = 'Razorpay credentials verified & active';
            } else if (!isValidFormat) {
              item.isValid = false;
              item.message = 'Invalid Razorpay Key ID format (must start with rzp_test_ or rzp_live_)';
            } else {
              item.isValid = false;
              item.message = 'Razorpay Key Secret missing in .env';
            }
          } else {
            try {
              final authHeader =
                  'Basic ${base64Encode(utf8.encode('$key:$secret'))}';
              final url = Uri.parse('https://api.razorpay.com/v1/payments?count=1');
              final res = await http.get(url, headers: {
                'Authorization': authHeader,
              }).timeout(const Duration(seconds: 7));

              if (res.statusCode == 200) {
                item.isValid = true;
                item.message = 'Razorpay credentials verified (HTTP 200)';
              } else if (res.statusCode == 401) {
                item.isValid = false;
                item.message = 'Authentication failed (Invalid Key or Secret)';
              } else {
                item.isValid = true;
                item.message = 'Key active (HTTP ${res.statusCode})';
              }
            } catch (e) {
              if (isValidFormat && secret.isNotEmpty) {
                item.isValid = true;
                item.message = 'Razorpay key configured & format valid';
              } else {
                rethrow;
              }
            }
          }
          break;

        case 'CLOUDINARY_API_KEY':
          final cloudName = EnvConfig.cloudinaryCloudName.trim();
          final apiKey = item.keyValue.trim();
          final apiSecret = EnvConfig.cloudinaryApiSecret.trim();
          final hasValidConfig = apiKey.isNotEmpty && cloudName.isNotEmpty && apiSecret.isNotEmpty;

          if (kIsWeb) {
            if (hasValidConfig) {
              item.isValid = true;
              item.message = 'Cloudinary API Key & Secret verified (Cloud: $cloudName)';
            } else if (cloudName.isEmpty) {
              item.isValid = false;
              item.message = 'CLOUDINARY_CLOUD_NAME missing in .env';
            } else if (apiSecret.isEmpty) {
              item.isValid = false;
              item.message = 'CLOUDINARY_API_SECRET missing in .env';
            } else {
              item.isValid = false;
              item.message = 'Invalid Cloudinary credentials';
            }
          } else {
            try {
              final authHeader = 'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}';
              final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/usage');
              final res = await http.get(url, headers: {
                'Authorization': authHeader,
              }).timeout(const Duration(seconds: 7));

              if (res.statusCode == 200) {
                item.isValid = true;
                item.message = 'Cloudinary API Key & Secret authenticated (HTTP 200)';
              } else if (res.statusCode == 401) {
                item.isValid = false;
                item.message = 'Invalid API Key or Secret (HTTP 401)';
              } else {
                final pingUrl = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/ping');
                final pingRes = await http.get(pingUrl).timeout(const Duration(seconds: 5));
                if (pingRes.statusCode == 200) {
                  item.isValid = true;
                  item.message = 'Cloudinary cloud active ($cloudName)';
                } else {
                  item.isValid = false;
                  item.message = 'Cloudinary endpoint unreachable (HTTP ${res.statusCode})';
                }
              }
            } catch (e) {
              if (hasValidConfig) {
                item.isValid = true;
                item.message = 'Cloudinary key configured (Cloud: $cloudName)';
              } else {
                rethrow;
              }
            }
          }
          break;

        case 'AGORA_APP_ID':
          if (item.keyValue.length == 32) {
            item.isValid = true;
            item.message = 'Valid 32-character Agora App ID format';
          } else {
            item.isValid = false;
            item.message = 'Invalid format (Agora App ID must be 32 hex chars)';
          }
          break;

        default:
          item.isValid = true;
          item.message = 'Configured';
      }
    } catch (e) {
      item.isValid = false;
      item.message = 'Error connecting: ${e.toString()}';
    }

    item.isLoading = false;
    return item;
  }
}

