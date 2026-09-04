import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

enum NetworkShareType { wifi, hotspot, usbTethering, ethernet, other }

class NetworkShareInfo {
  final String ipAddress;
  final String interfaceName;
  final NetworkShareType type;
  final String displayName;

  const NetworkShareInfo({
    required this.ipAddress,
    required this.interfaceName,
    required this.type,
    required this.displayName,
  });
}

enum WebShareEventType {
  serverStarted,
  clientConnected,
  fileDownloaded,
  serverStopped,
  error,
}

class WebShareEvent {
  final WebShareEventType type;
  final String? message;
  final int? fileIndex;
  final String? clientAddress;

  const WebShareEvent({
    required this.type,
    this.message,
    this.fileIndex,
    this.clientAddress,
  });
}

class WebShareService {
  HttpServer? _server;
  List<String> _filePaths = [];
  String? _ipAddress;
  int? _port;
  List<NetworkShareInfo> _availableNetworks = [];

  final StreamController<WebShareEvent> _eventController =
      StreamController<WebShareEvent>.broadcast();

  Stream<WebShareEvent> get eventStream => _eventController.stream;

  bool get isRunning => _server != null;
  String? get ipAddress => _ipAddress;
  int? get port => _port;
  String? get serverUrl =>
      _ipAddress != null && _port != null ? 'http://$_ipAddress:$_port' : null;
  List<String> get filePaths => List.unmodifiable(_filePaths);
  List<NetworkShareInfo> get availableNetworks =>
      List.unmodifiable(_availableNetworks);

  /// Changes the currently targeted IP address (e.g. switching between Wi-Fi and Hotspot)
  /// without needing to restart the server since HttpServer binds to 0.0.0.0.
  void setIpAddress(String newIp) {
    if (_ipAddress != newIp) {
      _ipAddress = newIp;
      if (_server != null && _port != null) {
        _emit(
          WebShareEvent(
            type: WebShareEventType.serverStarted,
            message: 'Switched to http://$_ipAddress:$_port',
          ),
        );
      }
    }
  }

  /// Discovers all available IPv4 network interfaces on the device
  /// (Hotspot, Wi-Fi, USB tethering, Ethernet) and categorizes them.
  static Future<List<NetworkShareInfo>> getAvailableNetworks() async {
    final List<NetworkShareInfo> results = [];
    final Set<String> seenIps = {};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();

        // Skip cellular/virtual/dummy interfaces
        if (name.startsWith('rmnet') ||
            name.startsWith('ccmni') ||
            name.startsWith('dummy') ||
            name.startsWith('ifb') ||
            name.startsWith('tun') ||
            name.startsWith('gre')) {
          continue;
        }

        NetworkShareType type = NetworkShareType.other;
        String displayName = 'Local Network';

        if (name.contains('ap') || name.contains('softap')) {
          type = NetworkShareType.hotspot;
          displayName = 'Mobile Hotspot';
        } else if (name.contains('wlan')) {
          type = NetworkShareType.wifi;
          displayName = 'Wi-Fi Network';
        } else if (name.contains('rndis') || name.contains('usb')) {
          type = NetworkShareType.usbTethering;
          displayName = 'USB Tethering';
        } else if (name.contains('en') || name.contains('eth')) {
          type = NetworkShareType.ethernet;
          displayName = 'Ethernet / Wi-Fi';
        }

        for (final addr in iface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('169.254.') &&
              !seenIps.contains(addr.address)) {
            seenIps.add(addr.address);
            results.add(
              NetworkShareInfo(
                ipAddress: addr.address,
                interfaceName: iface.name,
                type: type,
                displayName: displayName,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[WebShareService] Error listing network interfaces: $e');
    }

    // Try NetworkInfo().getWifiIP() to complement Wi-Fi IP if missing
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null &&
          wifiIp.isNotEmpty &&
          wifiIp != '0.0.0.0' &&
          !wifiIp.startsWith('169.254.') &&
          !seenIps.contains(wifiIp)) {
        seenIps.add(wifiIp);
        results.add(
          NetworkShareInfo(
            ipAddress: wifiIp,
            interfaceName: 'wlan0',
            type: NetworkShareType.wifi,
            displayName: 'Wi-Fi Network',
          ),
        );
      }
    } catch (e) {
      debugPrint('[WebShareService] Error getting Wi-Fi IP via NetworkInfo: $e');
    }

    // If still empty, search all non-loopback IPv4 as fallback
    if (results.isEmpty) {
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback &&
                addr.type == InternetAddressType.IPv4 &&
                !seenIps.contains(addr.address)) {
              seenIps.add(addr.address);
              results.add(
                NetworkShareInfo(
                  ipAddress: addr.address,
                  interfaceName: iface.name,
                  type: NetworkShareType.other,
                  displayName: 'Network (${iface.name})',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // Sort order: Mobile Hotspot first (since it guarantees bypass of router AP isolation),
    // then Wi-Fi, then USB tethering, etc.
    results.sort((a, b) {
      int score(NetworkShareType t) {
        switch (t) {
          case NetworkShareType.hotspot:
            return 0;
          case NetworkShareType.wifi:
            return 1;
          case NetworkShareType.usbTethering:
            return 2;
          case NetworkShareType.ethernet:
            return 3;
          case NetworkShareType.other:
            return 4;
        }
      }

      return score(a.type).compareTo(score(b.type));
    });

    return results;
  }

  /// Discovers the local IPv4 address of the device.
  static Future<String?> getLocalIpAddress() async {
    final networks = await getAvailableNetworks();
    return networks.isNotEmpty ? networks.first.ipAddress : null;
  }

  /// Starts the embedded HTTP server to share the given files.
  Future<String> startServer({
    required List<String> filePaths,
    int preferredPort = 8080,
    String? selectedIp,
  }) async {
    await stopServer();

    _filePaths = filePaths.where((f) => File(f).existsSync()).toList();
    if (_filePaths.isEmpty) {
      throw Exception('No valid files provided to share');
    }

    _availableNetworks = await getAvailableNetworks();
    if (_availableNetworks.isEmpty) {
      throw Exception(
        'No active Wi-Fi or Hotspot network detected. Please connect to Wi-Fi or enable Mobile Hotspot.',
      );
    }

    // If an IP was requested and is present, use it; otherwise use the top prioritized network
    if (selectedIp != null &&
        _availableNetworks.any((n) => n.ipAddress == selectedIp)) {
      _ipAddress = selectedIp;
    } else {
      _ipAddress = _availableNetworks.first.ipAddress;
    }

    // Bind to the preferred port, falling back to an ephemeral port if occupied
    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        preferredPort,
        shared: true,
      );
    } catch (_) {
      // Ephemeral port allocation
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        0,
        shared: true,
      );
    }

    _port = _server!.port;
    final url = 'http://$_ipAddress:$_port';

    _emit(
      WebShareEvent(
        type: WebShareEventType.serverStarted,
        message: 'Server started at $url',
      ),
    );

    // Listen for incoming requests
    _server!.listen(
      _handleRequest,
      onError: (error) {
        debugPrint('[WebShareService] Server error: $error');
        _emit(
          WebShareEvent(
            type: WebShareEventType.error,
            message: error.toString(),
          ),
        );
      },
    );

    return url;
  }

  /// Stops the running HTTP server.
  Future<void> stopServer() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (e) {
        debugPrint('[WebShareService] Error stopping server: $e');
      }
      _server = null;
      _ipAddress = null;
      _port = null;
      _emit(
        const WebShareEvent(
          type: WebShareEventType.serverStopped,
          message: 'Server stopped',
        ),
      );
    }
  }

  Future<void> dispose() async {
    await stopServer();
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  void _emit(WebShareEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final clientIp = request.connectionInfo?.remoteAddress.address;

    try {
      if (path == '/' || path == '/index.html') {
        _emit(
          WebShareEvent(
            type: WebShareEventType.clientConnected,
            clientAddress: clientIp,
            message: 'Client connected from $clientIp',
          ),
        );
        await _serveWebPage(request);
      } else if (path == '/image') {
        await _serveImage(request);
      } else if (path == '/download') {
        await _serveDownload(request, clientIp);
      } else if (path == '/download-all') {
        await _serveDownloadAll(request, clientIp);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.html
          ..write('<h1>404 Not Found</h1>');
        await request.response.close();
      }
    } catch (e) {
      debugPrint('[WebShareService] Error handling request: $e');
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Internal Server Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Serves the standalone modern HTML5 page.
  Future<void> _serveWebPage(HttpRequest request) async {
    final isMultiple = _filePaths.length > 1;
    var totalBytes = 0;
    for (final p in _filePaths) {
      final f = File(p);
      if (f.existsSync()) totalBytes += f.lengthSync();
    }

    final totalSizeStr = _formatBytes(totalBytes);

    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Image Tools - Send to PC</title>
  <style>
    :root {
      --bg: #0B0F17;
      --card-bg: #161E2E;
      --card-inner: #1E293B;
      --border: #334155;
      --primary: #2563EB;
      --primary-hover: #1D4ED8;
      --teal: #0D9488;
      --teal-hover: #0F766E;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --success: #16A34A;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px 16px;
      line-height: 1.5;
    }
    .container {
      width: 100%;
      max-width: 680px;
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 24px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      overflow: hidden;
    }
    .header {
      padding: 28px 24px 20px;
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: linear-gradient(135deg, rgba(37, 99, 235, 0.1) 0%, rgba(13, 148, 136, 0.08) 100%);
    }
    .logo-badge {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .logo-icon {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: linear-gradient(135deg, var(--primary) 0%, var(--teal) 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 12px rgba(37, 99, 235, 0.3);
    }
    .logo-icon svg {
      width: 24px;
      height: 24px;
      fill: white;
    }
    .title-group h1 {
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--text);
    }
    .title-group p {
      font-size: 0.85rem;
      color: var(--text-muted);
    }
    .status-pill {
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--teal);
      background: rgba(13, 148, 136, 0.15);
      border: 1px solid rgba(13, 148, 136, 0.3);
      padding: 4px 12px;
      border-radius: 20px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .status-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--teal);
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(0.8); }
    }
    .content {
      padding: 24px;
    }
    .badge-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 20px;
      padding: 12px 16px;
      background: var(--card-inner);
      border-radius: 14px;
      font-size: 0.875rem;
      color: var(--text-muted);
    }
    .badge-bar strong {
      color: var(--text);
    }
    .gallery-grid {
      display: grid;
      grid-template-columns: ${isMultiple ? 'repeat(auto-fill, minmax(240px, 1fr))' : '1fr'};
      gap: 16px;
      margin-bottom: 24px;
    }
    .image-card {
      background: var(--card-inner);
      border: 1px solid var(--border);
      border-radius: 16px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      transition: transform 0.2s ease, border-color 0.2s ease;
    }
    .image-card:hover {
      border-color: var(--primary);
      transform: translateY(-2px);
    }
    .preview-box {
      width: 100%;
      height: ${isMultiple ? '180px' : '300px'};
      background: #000000;
      display: flex;
      align-items: center;
      justify-content: center;
      overflow: hidden;
    }
    .preview-box img {
      max-width: 100%;
      max-height: 100%;
      object-fit: contain;
    }
    .image-meta {
      padding: 14px 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-grow: 1;
    }
    .file-name {
      font-size: 0.875rem;
      font-weight: 600;
      max-width: 140px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .file-size {
      font-size: 0.75rem;
      color: var(--text-muted);
    }
    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      font-size: 0.95rem;
      font-weight: 600;
      padding: 12px 20px;
      border-radius: 12px;
      text-decoration: none;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
    }
    .btn svg {
      width: 18px;
      height: 18px;
      fill: currentColor;
    }
    .btn-primary {
      background: linear-gradient(135deg, var(--primary) 0%, var(--teal) 100%);
      color: white;
      box-shadow: 0 4px 14px rgba(37, 99, 235, 0.4);
      width: 100%;
    }
    .btn-primary:hover {
      opacity: 0.95;
      transform: translateY(-1px);
    }
    .btn-primary:active {
      transform: translateY(0);
    }
    .btn-secondary {
      background: rgba(255, 255, 255, 0.08);
      color: var(--text);
      border: 1px solid var(--border);
      padding: 8px 14px;
      font-size: 0.8rem;
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.15);
      border-color: var(--primary);
    }
    .download-all-box {
      margin-bottom: 24px;
    }
    .footer-note {
      text-align: center;
      padding: 16px 24px;
      border-top: 1px solid var(--border);
      font-size: 0.8rem;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }
    .footer-note svg {
      width: 16px;
      height: 16px;
      fill: var(--teal);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo-badge">
        <div class="logo-icon">
          <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/></svg>
        </div>
        <div class="title-group">
          <h1>Image Tools Web Share</h1>
          <p>Local Wi-Fi File Transfer</p>
        </div>
      </div>
      <div class="status-pill">
        <div class="status-dot"></div>
        <span>Connected</span>
      </div>
    </div>

    <div class="content">
      <div class="badge-bar">
        <span>Files Ready: <strong>${_filePaths.length}</strong></span>
        <span>Total Size: <strong>$totalSizeStr</strong></span>
      </div>

      ${isMultiple ? '''
      <div class="download-all-box">
        <a href="/download-all" class="btn btn-primary" onclick="markDownloading(this)">
          <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z"/></svg>
          Download All as ZIP Archive ($totalSizeStr)
        </a>
      </div>
      ''' : ''}

      <div class="gallery-grid">
        ${_generateImageCardsHtml()}
      </div>

      ${!isMultiple ? '''
      <a href="/download?index=0" class="btn btn-primary" onclick="markDownloading(this)">
        <svg viewBox="0 0 24 24"><path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/></svg>
        Download Image (${_formatBytes(File(_filePaths[0]).lengthSync())})
      </a>
      ''' : ''}
    </div>

    <div class="footer-note">
      <svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z"/></svg>
      <span>100% Offline & Private. Files are served directly from phone memory over your local network.</span>
    </div>
  </div>

  <script>
    function markDownloading(btn) {
      const original = btn.innerHTML;
      btn.innerHTML = '<span>⏳ Downloading...</span>';
      setTimeout(() => {
        btn.innerHTML = original;
      }, 3000);
    }
  </script>
</body>
</html>
''';

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(html);
    await request.response.close();
  }

  String _generateImageCardsHtml() {
    final buffer = StringBuffer();
    for (var i = 0; i < _filePaths.length; i++) {
      final path = _filePaths[i];
      final file = File(path);
      final fileName = p.basename(path);
      final sizeStr = file.existsSync() ? _formatBytes(file.lengthSync()) : '0 B';

      buffer.writeln('''
      <div class="image-card">
        <div class="preview-box">
          <img src="/image?index=$i" alt="$fileName" loading="lazy" />
        </div>
        <div class="image-meta">
          <div>
            <div class="file-name" title="$fileName">$fileName</div>
            <div class="file-size">$sizeStr</div>
          </div>
          <a href="/download?index=$i" class="btn btn-secondary" onclick="markDownloading(this)">
            Download
          </a>
        </div>
      </div>
      ''');
    }
    return buffer.toString();
  }

  /// Serves the raw image bytes for preview in browser.
  Future<void> _serveImage(HttpRequest request) async {
    final indexParam = request.uri.queryParameters['index'] ?? '0';
    final index = int.tryParse(indexParam) ?? 0;

    if (index < 0 || index >= _filePaths.length) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Image not found');
      await request.response.close();
      return;
    }

    final file = File(_filePaths[index]);
    if (!file.existsSync()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('File does not exist on disk');
      await request.response.close();
      return;
    }

    final mimeType = _getMimeType(file.path);
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, mimeType)
      ..headers.set(HttpHeaders.contentLengthHeader, file.lengthSync().toString())
      ..headers.set(HttpHeaders.cacheControlHeader, 'public, max-age=3600');

    await file.openRead().pipe(request.response);
  }

  /// Serves the file as an attachment to trigger direct download on PC.
  Future<void> _serveDownload(HttpRequest request, String? clientIp) async {
    final indexParam = request.uri.queryParameters['index'] ?? '0';
    final index = int.tryParse(indexParam) ?? 0;

    if (index < 0 || index >= _filePaths.length) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('File not found');
      await request.response.close();
      return;
    }

    final file = File(_filePaths[index]);
    if (!file.existsSync()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('File does not exist on disk');
      await request.response.close();
      return;
    }

    final fileName = p.basename(file.path);
    final mimeType = _getMimeType(file.path);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, mimeType)
      ..headers.set(HttpHeaders.contentLengthHeader, file.lengthSync().toString())
      ..headers.set(
        'Content-Disposition',
        'attachment; filename="$fileName"',
      );

    await file.openRead().pipe(request.response);

    _emit(
      WebShareEvent(
        type: WebShareEventType.fileDownloaded,
        fileIndex: index,
        clientAddress: clientIp,
        message: 'Downloaded $fileName',
      ),
    );
  }

  /// Serves all files bundled as a ZIP archive.
  Future<void> _serveDownloadAll(HttpRequest request, String? clientIp) async {
    if (_filePaths.length == 1) {
      await _serveDownload(request, clientIp);
      return;
    }

    final archive = Archive();
    for (final path in _filePaths) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final fileName = p.basename(path);
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    if (zipBytes.isEmpty) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Failed to generate ZIP archive');
      await request.response.close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, 'application/zip')
      ..headers.set(HttpHeaders.contentLengthHeader, zipBytes.length.toString())
      ..headers.set(
        'Content-Disposition',
        'attachment; filename="image_tools_batch.zip"',
      )
      ..add(zipBytes);

    await request.response.close();

    _emit(
      WebShareEvent(
        type: WebShareEventType.fileDownloaded,
        clientAddress: clientIp,
        message: 'Downloaded all files as ZIP',
      ),
    );
  }

  static String _getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
