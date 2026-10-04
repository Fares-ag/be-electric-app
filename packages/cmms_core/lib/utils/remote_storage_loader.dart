import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/locator.dart';
import '../services/supabase_auth_service.dart';

/// Downloads a remote file from HTTP(S) or Supabase Storage.
class RemoteStorageLoader {
  static Future<Uint8List> loadBytes(String url) async {
    final isFirebaseStorageUrl = url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com');
    final isSupabaseStorageUrl = url.contains('supabase.co/storage');

    if (isFirebaseStorageUrl) {
      return _loadWithAuth(url);
    }
    if (isSupabaseStorageUrl) {
      return _loadSupabaseStorage(url);
    }
    return _loadWithoutAuth(url);
  }

  static ({String bucket, String path})? _parseSupabaseStorageUrl(String url) {
    const publicPrefix = '/object/public/';
    const signPrefix = '/object/sign/';
    final uri = Uri.parse(url);
    final pathSegment = uri.path;
    String? suffix;
    if (pathSegment.contains(publicPrefix)) {
      final i = pathSegment.indexOf(publicPrefix);
      suffix = pathSegment.substring(i + publicPrefix.length);
    } else if (pathSegment.contains(signPrefix)) {
      final i = pathSegment.indexOf(signPrefix);
      suffix = pathSegment.substring(i + signPrefix.length);
    }
    if (suffix == null || suffix.isEmpty) return null;
    final parts = suffix.split('/');
    if (parts.length < 2) return null;
    final bucket = parts.first;
    final path = parts.sublist(1).join('/');
    return (bucket: bucket, path: path);
  }

  static Future<Uint8List> _loadSupabaseStorage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    final parsed = _parseSupabaseStorageUrl(url);
    if (parsed == null) {
      throw Exception('Could not load file (HTTP ${response.statusCode})');
    }

    final signedUrl = await Supabase.instance.client.storage
        .from(parsed.bucket)
        .createSignedUrl(parsed.path, 3600);
    final signedResponse = await http.get(Uri.parse(signedUrl));
    if (signedResponse.statusCode == 200) {
      return signedResponse.bodyBytes;
    }
    throw Exception('Could not load file (HTTP ${signedResponse.statusCode})');
  }

  static Future<Uint8List> _loadWithAuth(String url) async {
    final authService = sl<SupabaseAuthService>();
    final token = await authService.getIdToken();

    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return _loadWithoutAuth(url);
  }

  static Future<Uint8List> _loadWithoutAuth(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Could not load file (HTTP ${response.statusCode})');
  }
}
