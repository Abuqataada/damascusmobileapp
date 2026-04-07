import 'dart:ui';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'push_notifications.dart';
import 'recording_saver.dart';

const String kAppTitle = 'Damascus Projects';
const String kHomeUrl = 'https://app.damascusprojects.com';
const String kInternalHost = 'app.damascusprojects.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

    if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await [
      Permission.camera,
      Permission.microphone,
      if (defaultTargetPlatform == TargetPlatform.android) Permission.storage,
      Permission.notification,
    ].request();
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  PushNotificationService.instance.registerBackgroundHandler();

  try {
    await Firebase.initializeApp();
    await PushNotificationService.instance.initialize();
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Firebase initialization skipped: $error');
    }
  }

  runApp(const DamascusWebviewApp());
}

bool isInternalWebUri(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == kInternalHost || host.endsWith('.damascusprojects.com');
}

bool shouldOpenExternally(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme.isEmpty ||
      scheme == 'about' ||
      scheme == 'javascript' ||
      scheme == 'file' ||
      scheme == 'chrome' ||
      scheme == 'data' ||
      scheme == 'blob') {
    return false;
  }
  if (scheme == 'http' || scheme == 'https') {
    return !isInternalWebUri(uri);
  }
  return true;
}

class DamascusWebviewApp extends StatelessWidget {
  const DamascusWebviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F62FE),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: kAppTitle,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF07111F),
      ),
      home: const WebviewShellPage(),
    );
  }
}

class WebviewShellPage extends StatefulWidget {
  const WebviewShellPage({super.key});

  @override
  State<WebviewShellPage> createState() => _WebviewShellPageState();
}

class _WebviewShellPageState extends State<WebviewShellPage> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  StreamSubscription<Uri?>? _notificationTapSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Uri? _queuedNavigation;
  String? _errorMessage;
  double _progress = 0;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: const Color(0xFF0F62FE),
        backgroundColor: const Color(0xFF0B1626),
      ),
      onRefresh: () async {
        await _controller?.reload();
      },
    );

    _notificationTapSubscription =
        NotificationNavigationBus.instance.stream.listen((uri) {
      _handleNotificationTap(uri);
    });

    final initialTap = NotificationNavigationBus.instance.consumePendingTap();
    if (initialTap != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationTap(initialTap);
      });
    }

    _initializeConnectivity();
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _pullToRefreshController?.dispose();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    final connectivity = Connectivity();
    final initialResults = await connectivity.checkConnectivity();
    _applyConnectivityResults(initialResults);

    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _applyConnectivityResults,
    );
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    final offline = results.isEmpty || results.contains(ConnectivityResult.none);
    if (!mounted) {
      _isOffline = offline;
      return;
    }

    setState(() {
      _isOffline = offline;
      if (!offline) {
        _errorMessage = null;
      }
    });
  }

  Future<void> _syncNavigationState() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await controller.getUrl();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _refreshPage() async {
    await _controller?.reload();
  }

  Future<void> _launchExternalUrl(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleBackPressed() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }

    SystemNavigator.pop();
  }

  Future<void> _handleNotificationTap(Uri? uri) async {
    if (uri == null) {
      return;
    }

    if (_controller == null) {
      _queuedNavigation = uri;
      return;
    }

    if (shouldOpenExternally(uri)) {
      await _launchExternalUrl(uri);
      return;
    }

    await _controller?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(uri.toString()),
      ),
    );
  }

  Future<void> _flushQueuedNavigation() async {
    final uri = _queuedNavigation;
    if (uri == null) {
      return;
    }

    _queuedNavigation = null;
    await _handleNotificationTap(uri);
  }

  Future<void> _saveRecordingPayload(Map<dynamic, dynamic> payload) async {
    final base64Data = payload['data']?.toString();
    if (base64Data == null || base64Data.isEmpty) {
      return;
    }

    final rawName = payload['name']?.toString().trim();
    final fileName = (rawName == null || rawName.isEmpty)
        ? 'live_stream_${DateTime.now().millisecondsSinceEpoch}.webm'
        : rawName.endsWith('.webm')
            ? rawName
            : '$rawName.webm';

    final savedPath = await saveRecordingFromBase64(
      fileName: fileName,
      base64Data: base64Data,
    );

    if (savedPath != null && kDebugMode) {
      debugPrint('Recording saved to: $savedPath');
    }
  }

  Widget _buildErrorOverlay(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        color: const Color(0xFF050B14).withValues(alpha: 0.96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1220).withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 36,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load the app',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage ?? 'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _refreshPage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _handleBackPressed();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF07111F),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF07111F),
          body: Stack(
            children: [
              Positioned.fill(
                child: InAppWebView(
                  key: const ValueKey('damascus-webview'),
                  initialUrlRequest: URLRequest(
                    url: WebUri(kHomeUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    isInspectable: kDebugMode,
                    javaScriptEnabled: true,
                    domStorageEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    iframeAllow: 'camera; microphone; autoplay; fullscreen',
                    iframeAllowFullscreen: true,
                    transparentBackground: true,
                    useShouldOverrideUrlLoading: true,
                    supportZoom: true,
                    sharedCookiesEnabled: true,
                    thirdPartyCookiesEnabled: true,
                  ),
                  pullToRefreshController: _pullToRefreshController,
                  onWebViewCreated: (controller) {
                    _controller = controller;
                    controller.addJavaScriptHandler(
                      handlerName: 'saveRecording',
                      callback: (arguments) async {
                        if (arguments.isEmpty || arguments.first is! Map) {
                          return null;
                        }
                        await _saveRecordingPayload(arguments.first as Map<dynamic, dynamic>);
                        return null;
                      },
                    );
                    _syncNavigationState();
                    _flushQueuedNavigation();
                  },
                  shouldOverrideUrlLoading: (controller, navigationAction) async {
                    final requestedUrl = navigationAction.request.url;
                    final uri = requestedUrl == null
                        ? null
                        : Uri.tryParse(requestedUrl.toString());
                    if (uri == null) {
                      return NavigationActionPolicy.CANCEL;
                    }

                    if (shouldOpenExternally(uri)) {
                      await _launchExternalUrl(uri);
                      return NavigationActionPolicy.CANCEL;
                    }

                    return NavigationActionPolicy.ALLOW;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _errorMessage = null;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    _pullToRefreshController?.endRefreshing();
                    await _syncNavigationState();
                    if (mounted) {
                      setState(() {
                        _progress = 1;
                      });
                    }
                  },
                  onProgressChanged: (controller, progress) {
                    if (progress == 100) {
                      _pullToRefreshController?.endRefreshing();
                    }

                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  onReceivedError: (controller, request, error) {
                    _pullToRefreshController?.endRefreshing();
                    if (!mounted) {
                      return;
                    }

                    final mainFrameRequest = request.isForMainFrame == true;
                    final isLikelyOfflineError = <WebResourceErrorType>{
                      WebResourceErrorType.HOST_LOOKUP,
                      WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
                      WebResourceErrorType.TIMEOUT,
                      WebResourceErrorType.FAILED_SSL_HANDSHAKE,
                      WebResourceErrorType.NOT_CONNECTED_TO_INTERNET,
                      WebResourceErrorType.NETWORK_CONNECTION_LOST,
                      WebResourceErrorType.CANCELLED,
                    }.contains(error.type);

                    if (mainFrameRequest && (_isOffline || isLikelyOfflineError)) {
                      setState(() {
                        _errorMessage = 'Please check your internet connection and try again.';
                      });
                    }
                  },
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    _syncNavigationState();
                  },
                ),
              ),
              if (_progress < 1)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: _progress,
                    backgroundColor: scheme.primary.withValues(alpha: 0.14),
                  ),
                ),
              if (_errorMessage != null)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF020814).withValues(alpha: 0.995),
                    child: _buildErrorOverlay(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
