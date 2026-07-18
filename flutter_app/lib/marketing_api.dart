import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class SessionCredentials {
  const SessionCredentials(this.id, this.token, this.duration);
  final String id;
  final String token;
  final int duration;
}

class MarketingApi {
  MarketingApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://localhost:3000');
  Map<String, String> _headers(SessionCredentials s) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${s.token}'
      };

  Future<SessionCredentials> createSession(int duration) async {
    final response = await _client.post(Uri.parse('$_baseUrl/sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'duration_preset': duration}));
    final body = _decode(response, 201);
    return SessionCredentials(
        body['session_id'] as String, body['token'] as String, duration);
  }

  Future<Map<String, dynamic>> message(
          SessionCredentials s, String text) async =>
      _decode(
          await _client.post(Uri.parse('$_baseUrl/sessions/${s.id}/messages'),
              headers: _headers(s), body: jsonEncode({'text': text})),
          200,
          allowed: [429]);
  Future<Map<String, dynamic>> saveDetails(
          SessionCredentials s, Map<String, String> details) async =>
      _decode(
          await _client.post(Uri.parse('$_baseUrl/sessions/${s.id}/details'),
              headers: _headers(s), body: jsonEncode(details)),
          200);
  Future<Map<String, dynamic>> generateText(SessionCredentials s) async =>
      _decode(
          await _client.post(
              Uri.parse('$_baseUrl/sessions/${s.id}/generate-text'),
              headers: _headers(s)),
          200);
  Future<List<Map<String, dynamic>>> voices() async {
    final r = await _client.get(Uri.parse('$_baseUrl/voice-presets'));
    final body = _decode(r, 200);
    return List<Map<String, dynamic>>.from(body);
  }

  Future<void> generateSpeech(SessionCredentials s, String voiceId) async =>
      _decode(
          await _client.post(
              Uri.parse('$_baseUrl/sessions/${s.id}/generate-speech'),
              headers: _headers(s),
              body: jsonEncode(
                  {'voice_preset_id': voiceId, 'duration_preset': s.duration})),
          200);
  Future<File> downloadAudio(SessionCredentials s) async {
    final response = await _client.get(
        Uri.parse('$_baseUrl/sessions/${s.id}/audio'),
        headers: _headers(s));
    if (response.statusCode != 200) throw Exception('Audio is not available');
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/marketing-${s.id}.mp3');
    return file.writeAsBytes(response.bodyBytes);
  }

  dynamic _decode(http.Response response, int expected,
      {List<int> allowed = const []}) {
    final body =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode != expected &&
        !allowed.contains(response.statusCode)) {
      throw Exception(
          body is Map ? body['error'] ?? 'Request failed' : 'Request failed');
    }
    return body;
  }
}
