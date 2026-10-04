import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiTestService {
  static Future<Map<String, dynamic>> testApiConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.statusCode == 200
            ? 'API connection successful'
            : 'API connection failed',
        'body': response.body,
      };
    } catch (e, st) {
      return {
        'success': false,
        'statusCode': 0,
        'message': 'API connection error: $e',
        'body': '',
      };
    }
  }

  static Future<Map<String, dynamic>> testWithApiKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assetsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.statusCode == 200
            ? 'API key authentication successful'
            : 'API key authentication failed',
        'body': response.body,
      };
    } catch (e, st) {
      return {
        'success': false,
        'statusCode': 0,
        'message': 'API key test error: $e',
        'body': '',
      };
    }
  }

  static Future<Map<String, dynamic>> testWithBearerToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assetsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.statusCode == 200
            ? 'Bearer token authentication successful'
            : 'Bearer token authentication failed',
        'body': response.body,
      };
    } catch (e, st) {
      return {
        'success': false,
        'statusCode': 0,
        'message': 'Bearer token test error: $e',
        'body': '',
      };
    }
  }

  static Future<Map<String, dynamic>> testWithDemoToken() async {
    // Demo token for testing
    const demoToken = 'demo_token_12345';
    return testWithBearerToken(demoToken);
  }

  static Future<Map<String, dynamic>> testGetAllAssets() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.assetsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      final assets = data['data'] as List? ?? [];

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.statusCode == 200
            ? 'Assets retrieved successfully (${assets.length} items)'
            : 'Failed to retrieve assets',
        'body': response.body,
        'assetCount': assets.length,
      };
    } catch (e, st) {
      return {
        'success': false,
        'statusCode': 0,
        'message': 'Get assets test error: $e',
        'body': '',
        'assetCount': 0,
      };
    }
  }
}





