import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/env_config.dart';

class CloudinaryService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery or camera (Universal: Web & Mobile)
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }

  /// Upload image bytes directly to Cloudinary CDN (Universal: Web & Mobile)
  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final cloudName = EnvConfig.cloudinaryCloudName;
      final apiKey = EnvConfig.cloudinaryApiKey;
      final apiSecret = EnvConfig.cloudinaryApiSecret;
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // 1. Try signed upload with SHA-1 signature
      if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
        final toSign = 'timestamp=$timestamp$apiSecret';
        final signature = sha1.convert(utf8.encode(toSign)).toString();

        final request = http.MultipartRequest('POST', url)
          ..fields['api_key'] = apiKey
          ..fields['timestamp'] = timestamp
          ..fields['signature'] = signature
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: 'spot_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );

        final response = await request.send();
        final responseData = await response.stream.toBytes();
        final responseString = utf8.decode(responseData);

        if (response.statusCode == 200) {
          final jsonMap = jsonDecode(responseString);
          final secureUrl = jsonMap['secure_url'] as String?;
          if (secureUrl != null && secureUrl.isNotEmpty) {
            return secureUrl;
          }
        } else {
          debugPrint('Signed Cloudinary upload status ${response.statusCode}: $responseString');
        }
      }

      // 2. Try unsigned upload with upload preset as fallback
      final uploadPreset = EnvConfig.cloudinaryUploadPreset;
      if (uploadPreset.isNotEmpty) {
        final unReq = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: 'spot_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          );

        final unRes = await unReq.send();
        final unData = await unRes.stream.toBytes();
        final unString = utf8.decode(unData);

        if (unRes.statusCode == 200) {
          final unJson = jsonDecode(unString);
          final secureUrl = unJson['secure_url'] as String?;
          if (secureUrl != null && secureUrl.isNotEmpty) {
            return secureUrl;
          }
        } else {
          debugPrint('Unsigned Cloudinary upload status ${unRes.statusCode}: $unString');
        }
      }

      // 3. If Cloudinary network error, fallback to Data URI (Base64) so the real image works anywhere!
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      debugPrint('Cloudinary upload exception: $e');
      try {
        final bytes = await imageFile.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (_) {}
    }

    return null;
  }
}
