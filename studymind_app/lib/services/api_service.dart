import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// Change this to your machine's local IP if testing on a physical device
// e.g. 'http://192.168.1.100:8000/api'
const _base = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8000/api',
);

class ApiService {
  // ── Ingest ────────────────────────────────────────────────────────────────

  static Future<String> ingestTopic(String topic) async {
    final res = await http.post(
      Uri.parse('$_base/ingest/topic'),
      body: {'topic': topic},
    );
    _check(res);
    return jsonDecode(res.body)['session_id'];
  }

  static Future<String> ingestUrl(String url) async {
    final res = await http.post(
      Uri.parse('$_base/ingest/url'),
      body: {'url': url},
    );
    _check(res);
    return jsonDecode(res.body)['session_id'];
  }

  static Future<String> ingestPdf(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/ingest/pdf'));
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _check(res);
    return jsonDecode(res.body)['session_id'];
  }

  // ── Agent Steps ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> analyze(String sessionId) async {
    final res = await http.post(Uri.parse('$_base/study/$sessionId/analyze'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> summarize(String sessionId) async {
    final res = await http.post(Uri.parse('$_base/study/$sessionId/summarize'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> generate(String sessionId) async {
    final res = await http.post(Uri.parse('$_base/study/$sessionId/generate'));
    _check(res);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> submitQuiz(
      String sessionId, List<int> answers) async {
    final res = await http.post(
      Uri.parse('$_base/quiz/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'session_id': sessionId, 'answers': answers}),
    );
    _check(res);
    return jsonDecode(res.body);
  }

  static void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Request failed (${res.statusCode})');
    }
  }
}
