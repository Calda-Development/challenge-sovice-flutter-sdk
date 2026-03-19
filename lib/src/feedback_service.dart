import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'feedback_model.dart';

class FeedbackService {
  static Future<void> submit(
    FeedbackReport report,
    CaldaFeedbackConfig config,
  ) async {
    final uri = Uri.parse(config.apiUrl);

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${config.apiKey}'
      ..fields['projectId'] = config.projectId
      ..fields['title'] = report.title
      ..fields['description'] = report.description
      ..fields['tags'] = report.type.tag;

    if (report.screenshot != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          report.screenshot!,
          filename: 'screenshot.png',
          contentType: MediaType('image', 'png'),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw Exception('HTTP ${streamed.statusCode}: $body');
    }
  }
}
