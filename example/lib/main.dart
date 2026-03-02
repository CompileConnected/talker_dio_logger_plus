import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:talker_dio_logger_plus/talker_dio_logger_plus.dart';
import 'package:talker_flutter/talker_flutter.dart';

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
      settings: AdvancedDioLoggerSettings(
        // Print settings
        printRequestData: true,
        printRequestHeaders: true,
        printResponseData: true,
        printResponseHeaders: true,
        printResponseTime: true,

        // Security settings - hide sensitive headers
        hiddenHeaders: {'authorization', 'x-api-key', 'api-key', 'cookie'},
        hideAuthorizationValue: true,

        cardDisplayLimit: DisplayLimitRegistry(
          overrides: {HttpBodyType.image: DisplayLimit(maxBytes: 10 * 1024)},
        ),

        // Feature flags
        enableCurlGeneration: true,
        jsonSoftWrapTextValueAtWidth: 150,

        // if you want to disable file saver
        fileSaver: null,
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
      body: SafeArea(
        child: Padding(
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
                () => _makeRequest(
                  'https://jsonplaceholder.typicode.com/posts/1',
                ),
              ),
              _buildRequestButton(
                'GET JSON List',
                () =>
                    _makeRequest('https://jsonplaceholder.typicode.com/posts'),
              ),
              _buildRequestButton(
                'GET Large JSON',
                () => _makeRequest(
                  'https://jsonplaceholder.typicode.com/comments',
                ),
              ),
              _buildRequestButton('POST with Auth', () => _makePostRequest()),
              _buildRequestButton(
                'POST FormData (Multipart)',
                () => _makeFormDataRequest(),
              ),
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
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Content-type': 'application/json; charset=UTF-8'},
        ),
      );
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

  Future<void> _makeFormDataRequest() async {
    try {
      // Build a multipart/form-data body with text fields and a fake file part
      final formData = FormData.fromMap({
        'title': 'Multipart Test',
        'description': 'Testing FormData logging',
        'userId': '42',
        'attachment': MultipartFile.fromBytes(
          [72, 101, 108, 108, 111], // "Hello" as bytes
          filename: 'hello.txt',
          contentType: DioMediaType('text', 'plain'),
        ),
        'avatar': MultipartFile.fromBytes(
          // 1×1 transparent PNG
          [
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A,
            0x00,
            0x00,
            0x00,
            0x0D,
            0x49,
            0x48,
            0x44,
            0x52,
            0x00,
            0x00,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            0x01,
            0x08,
            0x06,
            0x00,
            0x00,
            0x00,
            0x1F,
            0x15,
            0xC4,
            0x89,
            0x00,
            0x00,
            0x00,
            0x0B,
            0x49,
            0x44,
            0x41,
            0x54,
            0x78,
            0x9C,
            0x62,
            0x00,
            0x01,
            0x00,
            0x00,
            0x05,
            0x00,
            0x01,
            0x0D,
            0x0A,
            0x2D,
            0xB4,
            0x00,
            0x00,
            0x00,
            0x00,
            0x49,
            0x45,
            0x4E,
            0x44,
            0xAE,
            0x42,
            0x60,
            0x82,
          ],
          filename: 'avatar.png',
          contentType: DioMediaType('image', 'png'),
        ),
      });

      final response = await _dio.post(
        'https://httpbin.org/post',
        data: formData,
      );
      _showSnackBar('FormData posted: ${response.statusCode}');
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
    // Define a custom theme for the talker screen
    // This theme will be automatically propagated to all child screens
    // via TalkerThemeProvider (InheritedWidget) - no prop drilling needed!
    const theme = TalkerScreenTheme(
      // You can customize colors here:
      // backgroundColor: Colors.black,
      // cardColor: Color(0xFF1E1E1E),
      // textColor: Colors.white,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => TalkerScreen(
              talker: _talker,
              theme: theme,
              // Use the custom HTTP log card builder
              itemsBuilder: (context, data) {
                if (isAdvancedHttpLog(data)) {
                  // HttpLogCard automatically wraps child navigations with
                  // TalkerThemeProvider, so detail screens (HttpDetailScreen,
                  // FullScreenImageViewer, FullScreenHtmlPreview) can access
                  // the theme via TalkerThemeProvider.of(context)
                  return HttpLogCard(data: data, expanded: true, theme: theme);
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
