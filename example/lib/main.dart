import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_dio_logger_plus/talker_dio_logger_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Dio Logger Demo',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Talker _talker;
  late final Dio _dio;
  late final AdvancedDioLogger _logger;

  @override
  void initState() {
    super.initState();
    _talker = Talker();

    // Create the advanced logger with custom settings
    _logger = AdvancedDioLogger(
      talker: _talker,
      settings: const AdvancedDioLoggerSettings(
        // Print settings
        printRequestData: true,
        printRequestHeaders: true,
        printResponseData: true,
        printResponseHeaders: true,
        printResponseTime: true,

        // Security settings - hide sensitive headers
        hiddenHeaders: {'authorization', 'x-api-key', 'api-key', 'cookie'},
        hideAuthorizationValue: true,

        // Truncation settings
        truncateThreshold: 100 * 1024, // 100KB
        maxDisplaySize: 1024 * 1024, // 1MB
        imagePreviewThreshold: 500 * 1024, // 500KB
        maxInlineJsonLines: 20,

        // Feature flags
        enableCurlGeneration: true,
        enableJsonViewer: true,
        enableImagePreview: true,
        enableHtmlPreview: true,
        enableDownload: true,
      ),
    );

    _dio = Dio();
    _dio.interceptors.add(_logger);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Dio Logger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _openTalkerScreen(context),
            tooltip: 'View Logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test API Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRequestButton(
              'GET JSON',
              () =>
                  _makeRequest('https://jsonplaceholder.typicode.com/posts/1'),
            ),
            _buildRequestButton(
              'GET JSON List',
              () => _makeRequest('https://jsonplaceholder.typicode.com/posts'),
            ),
            _buildRequestButton(
              'GET Large JSON',
              () =>
                  _makeRequest('https://jsonplaceholder.typicode.com/comments'),
            ),
            _buildRequestButton('POST with Auth', () => _makePostRequest()),
            _buildRequestButton('GET Image', () => _makeImageRequest()),
            _buildRequestButton('GET HTML', () => _makeHtmlRequest()),
            _buildRequestButton('GET 404 Error', () => _makeErrorRequest()),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openTalkerScreen(context),
              icon: const Icon(Icons.bug_report),
              label: const Text('Open Talker Logs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }

  Future<void> _makeRequest(String url) async {
    try {
      final response = await _dio.get(url);
      _showSnackBar('Success: ${response.statusCode}');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _makePostRequest() async {
    try {
      final response = await _dio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: {
          'title': 'Test Post',
          'body': 'This is a test post body',
          'userId': 1,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test',
            'X-API-Key': 'secret-api-key-12345',
            'Content-Type': 'application/json',
          },
        ),
      );
      _showSnackBar('Posted: ${response.statusCode}');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _makeImageRequest() async {
    try {
      final response = await _dio.get(
        'https://picsum.photos/200',
        options: Options(responseType: ResponseType.bytes),
      );
      _showSnackBar('Image loaded: ${response.data.length} bytes');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _makeHtmlRequest() async {
    try {
      final response = await _dio.get('https://example.com');
      _showSnackBar('HTML loaded: ${response.statusCode}');
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _makeErrorRequest() async {
    try {
      await _dio.get('https://jsonplaceholder.typicode.com/posts/9999999');
    } catch (e) {
      _showSnackBar('Error captured in logs');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openTalkerScreen(BuildContext context) {
    const theme = TalkerScreenTheme();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => TalkerScreen(
              talker: _talker,
              theme: theme,
              // Use the custom HTTP log card builder
              itemsBuilder: (context, data) {
                if (isAdvancedHttpLog(data)) {
                  return HttpLogCard(data: data, expanded: true);
                }
                // Return default card for non-advanced logs
                return TalkerDataCard(
                  data: data,
                  color: theme.logColors[data.key] ?? Colors.grey,
                  backgroundColor: const Color.fromARGB(255, 49, 49, 49),
                );
              },
            ),
      ),
    );
  }
}
