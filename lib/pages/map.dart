import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Houston Heat Map',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HeatMapPage(),
    );
  }
}

class HeatMapPage extends StatefulWidget {
  const HeatMapPage({super.key});

  @override
  State<HeatMapPage> createState() => _HeatMapPageState();
}

class _HeatMapPageState extends State<HeatMapPage> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initWebView();
  }

  Future<void> initWebView() async {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🔄 Page started loading: $url');
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            print('✅ Page finished loading: $url');
            setState(() {
              isLoading = false;
            });
            // Check console logs from the web page
            _checkWebViewConsole();
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
            print('   Error code: ${error.errorCode}');
            print('   Error type: ${error.errorType}');
            print('   Failed URL: ${error.url}');
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        print('🌐 JS Console [${message.level.name}]: ${message.message}');
      });

    // Load from GitHub Pages
    try {
      await controller.loadRequest(
        Uri.parse('https://alexcai13.github.io/houstonheat/'),
      );
      
      print('✅ Heat map loaded from GitHub Pages');
    } catch (e) {
      print('❌ Error loading heat map: $e');
    }
  }

  void _checkWebViewConsole() {
    // Run JavaScript to check if image loaded
    controller.runJavaScript('''
      console.log('=== WebView Debug Info ===');
      console.log('Canvas exists:', !!canvas);
      console.log('Image exists:', !!heatMapImage);
      if (heatMapImage) {
        console.log('Image loaded:', heatMapImage.complete);
        console.log('Image src:', heatMapImage.src);
        console.log('Image size:', heatMapImage.naturalWidth + 'x' + heatMapImage.naturalHeight);
      }
      console.log('========================');
    ''');
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.blue[50]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [Colors.blue[500]!, Colors.blue[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.thermostat,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'About Heat Map',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: CircleBorder(),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Description
                Text(
                  'This interactive heat map visualizes temperature variations across Houston. Each click shows you the adjusted \'feels-like\' temperature based on local conditions like tree coverage, building density, and surface materials. The heat score (0-10) helps identify urban heat islands where temperatures can be 5-10°F higher than surrounding areas.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Got it button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                    ),
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Custom AppBar with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 1.0],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 60,
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Info button on the left
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.grey),
                      onPressed: _showInfoDialog,
                      tooltip: 'About Heat Map',
                    ),
                    // Title in the center
                    Expanded(
                      child: Center(
                        child: Text(
                          'Houston Heat Map',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    // Refresh button on the right
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.grey),
                      onPressed: () {
                        controller.reload();
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
            ),
          ),
          // WebView takes remaining space
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: controller),
                if (isLoading)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading heat map...'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
