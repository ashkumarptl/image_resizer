import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/web_share_service.dart';
import 'gradient_button.dart';

class SendToPcSheet extends StatefulWidget {
  final List<String> filePaths;

  const SendToPcSheet({
    super.key,
    required this.filePaths,
  });

  /// Static helper to display the sheet from anywhere
  static Future<void> show(BuildContext context, {required List<String> filePaths}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendToPcSheet(filePaths: filePaths),
    );
  }

  @override
  State<SendToPcSheet> createState() => _SendToPcSheetState();
}

class _SendToPcSheetState extends State<SendToPcSheet> {
  final WebShareService _service = WebShareService();
  StreamSubscription<WebShareEvent>? _subscription;

  bool _isLoading = true;
  String? _errorMessage;
  String? _serverUrl;
  List<NetworkShareInfo> _networks = [];
  String? _selectedIp;

  String _statusText = 'Waiting for PC browser...';
  Color _statusColor = AppColors.warning;
  IconData _statusIcon = Icons.hourglass_top_rounded;
  int _downloadCount = 0;

  @override
  void initState() {
    super.initState();
    _startSharing();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> _startSharing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'Starting local web server...';
      _statusColor = AppColors.warning;
      _statusIcon = Icons.hourglass_top_rounded;
    });

    try {
      final url = await _service.startServer(filePaths: widget.filePaths);
      _networks = _service.availableNetworks;
      _selectedIp = _service.ipAddress;

      AnalyticsService.logSendToPcStarted(fileCount: widget.filePaths.length);

      _subscription = _service.eventStream.listen((event) {
        if (!mounted) return;
        setState(() {
          switch (event.type) {
            case WebShareEventType.clientConnected:
              _statusText = 'PC Browser Connected!';
              _statusColor = AppColors.primary;
              _statusIcon = Icons.laptop_chromebook_rounded;
              break;
            case WebShareEventType.fileDownloaded:
              _downloadCount++;
              _statusText = 'Downloaded to PC successfully! 🎉';
              _statusColor = AppColors.success;
              _statusIcon = Icons.check_circle_rounded;
              AnalyticsService.logSendToPcDownloaded(fileCount: widget.filePaths.length);
              break;
            case WebShareEventType.error:
              _statusText = 'Network warning: ${event.message}';
              _statusColor = AppColors.error;
              _statusIcon = Icons.error_outline_rounded;
              break;
            case WebShareEventType.serverStarted:
              _serverUrl = _service.serverUrl;
              break;
            case WebShareEventType.serverStopped:
              break;
          }
        });
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _serverUrl = url;
        _statusText = 'Waiting for PC browser...';
        _statusColor = AppColors.warning;
        _statusIcon = Icons.hourglass_top_rounded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onSelectNetwork(NetworkShareInfo net) {
    if (_selectedIp == net.ipAddress) return;
    setState(() {
      _selectedIp = net.ipAddress;
      _service.setIpAddress(net.ipAddress);
      _serverUrl = _service.serverUrl;
    });
  }

  void _copyUrlToClipboard() {
    if (_serverUrl == null) return;
    Clipboard.setData(ClipboardData(text: _serverUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Link copied! Paste it in your PC/laptop browser.'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileCount = widget.filePaths.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.laptop_chromebook_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send to PC / Browser',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$fileCount file${fileCount > 1 ? 's' : ''} · Local Wi-Fi / Hotspot',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoading) ...[
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 40),
              ] else if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to Start Share Server',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startSharing,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Live Status Badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_statusIcon, size: 18, color: _statusColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_networks.length > 1) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: _networks.map((net) {
                      final isSelected = _selectedIp == net.ipAddress;
                      IconData icon;
                      switch (net.type) {
                        case NetworkShareType.hotspot:
                          icon = Icons.wifi_tethering_rounded;
                          break;
                        case NetworkShareType.wifi:
                          icon = Icons.wifi_rounded;
                          break;
                        case NetworkShareType.usbTethering:
                          icon = Icons.usb_rounded;
                          break;
                        default:
                          icon = Icons.settings_ethernet_rounded;
                      }

                      return ChoiceChip(
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        label: Text(net.displayName),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                        onSelected: (_) => _onSelectNetwork(net),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _serverUrl!,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F172A),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Direct URL Box with Copy Button
                InkWell(
                  onTap: _copyUrlToClipboard,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link_rounded, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _serverUrl!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Step-by-Step Instructions
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                        : AppColors.surfaceVariantLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildStepRow(
                        step: '1',
                        text: 'Connect laptop to the same Wi-Fi network or Phone Hotspot.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildStepRow(
                        step: '2',
                        text: 'Scan QR code or open the link above in Chrome, Edge, Safari, or Firefox.',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Troubleshooting Expandable Box
                Material(
                  color: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.3)
                      : AppColors.surfaceVariantLight.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: const Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      title: const Text(
                        'Page not opening on your PC?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '1. Router AP Client Isolation (Very Common)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Many Wi-Fi routers (e.g. JioFiber, Airtel, office Wi-Fi) isolate devices, preventing your laptop from talking directly to your phone over Wi-Fi.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '👉 Instant Fix: Mobile Hotspot',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Turn ON your phone\'s Mobile Hotspot, connect your PC to the hotspot Wi-Fi, and select the "Mobile Hotspot" tab above.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '👉 USB Cable Option:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'If plugged in via USB, run "adb forward tcp:8080 tcp:8080" in your terminal and open http://localhost:8080 in your browser.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Close / Done Button
                GradientButton(
                  text: _downloadCount > 0 ? 'Done ($_downloadCount Downloaded)' : 'Done / Stop Sharing',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String step,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
