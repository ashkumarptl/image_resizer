import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radii.dart';
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
  bool _isCopied = false;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _startSharing();
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
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
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _serverUrl!));
    setState(() {
      _isCopied = true;
    });
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copied: $_serverUrl\nOpen in Chrome / Edge on your PC/Laptop',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardSmallRadius),
        duration: const Duration(seconds: 2),
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
        borderRadius: AppRadii.sheetRadius,
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
                      borderRadius: AppRadii.cardSmallRadius,
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
                          '$fileCount file${fileCount > 1 ? 's' : ''} · Cyber Cafe & Form Fillers Transfer',
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
                    borderRadius: AppRadii.cardRadius,
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
                    borderRadius: AppRadii.cardSmallRadius,
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

                // QR Code Container (Large & Clean)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadii.dialogRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _serverUrl!,
                        version: QrVersions.auto,
                        size: 210.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scan with laptop webcam or camera',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Clickable Local IP URL Box with Dedicated "Copy IP" Button
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _copyUrlToClipboard,
                              borderRadius: AppRadii.cardInnerRadius,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: AppRadii.cardInnerSmallRadius,
                                      ),
                                      child: const Icon(
                                        Icons.language_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'LOCAL IP URL',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _serverUrl!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                              color: AppColors.primary,
                                              letterSpacing: 0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _copyUrlToClipboard,
                            icon: Icon(
                              _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                              size: 15,
                            ),
                            label: Text(
                              _isCopied ? 'Copied!' : 'Copy IP',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCopied ? AppColors.success : AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppRadii.cardInnerRadius,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '💡 Type this link in Chrome or Edge on your PC if camera is not available',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3-Step Visual Graphics Guide
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark.withValues(alpha: 0.45)
                        : AppColors.surfaceVariantLight.withValues(alpha: 0.8),
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadii.badgeRadius,
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'HOW TO TRANSFER IN 3 EASY STEPS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildVisualStep(
                        stepNumber: '1',
                        icon: Icons.wifi_tethering_rounded,
                        iconColor: AppColors.primary,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        ),
                        title: 'Connect Same Network',
                        description: 'Connect laptop to the same Wi-Fi network or Phone Hotspot.',
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildVisualStep(
                        stepNumber: '2',
                        icon: Icons.laptop_chromebook_rounded,
                        iconColor: AppColors.secondary,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                        ),
                        title: 'Open in PC Browser',
                        description: 'Scan QR code or open the link above in Chrome, Edge, Safari, or Firefox.',
                        isDark: isDark,
                        showDivider: true,
                      ),
                      _buildVisualStep(
                        stepNumber: '3',
                        icon: Icons.file_download_done_rounded,
                        iconColor: AppColors.success,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
                        ),
                        title: 'Instant Download for Forms',
                        description: 'Click Download on PC browser and upload straight to your online application form.',
                        isDark: isDark,
                        showDivider: false,
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
                    borderRadius: AppRadii.cardSmallRadius,
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

  Widget _buildVisualStep({
    required String stepNumber,
    required IconData icon,
    required Color iconColor,
    required Gradient gradient,
    required String title,
    required String description,
    required bool isDark,
    required bool showDivider,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Graphic Column: Icon Avatar + Connector Line
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: AppRadii.cardSmallRadius,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              if (showDivider)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content Column
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showDivider ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: AppRadii.badgeRadius,
                        ),
                        child: Text(
                          'STEP $stepNumber',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
