import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/integration_env.dart';

void main() {
  group('Supabase live integration', () {
    test('Supabase REST config is available when env is set', () {
      expect(
        IntegrationEnv.hasSupabaseConfig,
        isTrue,
        reason: 'Set SUPABASE_URL and SUPABASE_ANON_KEY for live tests',
      );
    }, skip: !IntegrationEnv.hasSupabaseConfig);

    test('anonymous REST client can read companies', () async {
      final res = await http.get(
        Uri.parse('${IntegrationEnv.supabaseRestUrl}/companies?limit=1'),
        headers: {
          'apikey': IntegrationEnv.supabaseAnonKey,
          'Authorization': 'Bearer ${IntegrationEnv.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
      );

      expect(res.statusCode, 200);
      expect(jsonDecode(res.body), isA<List>());
    }, skip: !IntegrationEnv.hasSupabaseConfig);

    test('requestor credentials sign in via Supabase Auth', () async {
      final res = await http.post(
        Uri.parse('${IntegrationEnv.supabaseAuthUrl}/token?grant_type=password'),
        headers: {
          'apikey': IntegrationEnv.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': IntegrationEnv.requestorEmail,
          'password': IntegrationEnv.requestorPassword,
        }),
      );

      expect(res.statusCode, 200, reason: res.body);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['access_token'], isNotEmpty);

      final accessToken = body['access_token'] as String;
      final usersRes = await http.get(
        Uri.parse(
          '${IntegrationEnv.supabaseRestUrl}/users?select=id,email,role,companyId&email=eq.${Uri.encodeComponent(IntegrationEnv.requestorEmail)}',
        ),
        headers: {
          'apikey': IntegrationEnv.supabaseAnonKey,
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      expect(usersRes.statusCode, 200, reason: usersRes.body);
      final users = jsonDecode(usersRes.body) as List;
      expect(users, isNotEmpty);

      final row = users.first as Map<String, dynamic>;
      expect(row['role'], 'requestor');
      expect(row['companyId'], isNotNull);
    }, skip: !IntegrationEnv.canRunLiveAuthTests);

    test('authenticated requestor can read company-scoped assets', () async {
      final tokenRes = await http.post(
        Uri.parse('${IntegrationEnv.supabaseAuthUrl}/token?grant_type=password'),
        headers: {
          'apikey': IntegrationEnv.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': IntegrationEnv.requestorEmail,
          'password': IntegrationEnv.requestorPassword,
        }),
      );
      expect(tokenRes.statusCode, 200, reason: tokenRes.body);
      final accessToken =
          (jsonDecode(tokenRes.body) as Map<String, dynamic>)['access_token']
              as String;

      final userRes = await http.get(
        Uri.parse(
          '${IntegrationEnv.supabaseRestUrl}/users?select=companyId&email=eq.${Uri.encodeComponent(IntegrationEnv.requestorEmail)}',
        ),
        headers: {
          'apikey': IntegrationEnv.supabaseAnonKey,
          'Authorization': 'Bearer $accessToken',
        },
      );
      expect(userRes.statusCode, 200, reason: userRes.body);
      final users = jsonDecode(userRes.body) as List;
      final companyId = (users.first as Map<String, dynamic>)['companyId'];
      expect(companyId, isNotNull);

      final assetsRes = await http.get(
        Uri.parse(
          '${IntegrationEnv.supabaseRestUrl}/assets?select=id,name,companyId&companyId=eq.$companyId&limit=5',
        ),
        headers: {
          'apikey': IntegrationEnv.supabaseAnonKey,
          'Authorization': 'Bearer $accessToken',
        },
      );

      expect(assetsRes.statusCode, 200, reason: assetsRes.body);
      expect(jsonDecode(assetsRes.body), isA<List>());
    }, skip: !IntegrationEnv.canRunLiveAuthTests);
  });
}
