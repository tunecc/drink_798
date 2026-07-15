import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../../core/theme/app_theme.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _isFlashOn = false;
  bool _isScanning = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 扫描视图
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: AppTheme.primaryColor,
              borderRadius: 16,
              borderLength: 32,
              borderWidth: 4,
              cutOutSize: MediaQuery.of(context).size.width * 0.7,
              overlayColor: Colors.black.withValues(alpha:0.7),
            ),
          ),

          // 顶部栏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(
                      Ionicons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Text(
                    '扫描设备二维码',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // 底部操作栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha:0.8),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 提示信息
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha:0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Ionicons.information_circle_outline,
                            color: Colors.white.withValues(alpha:0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '将设备二维码放入框内自动扫描',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha:0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 闪光灯按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          icon: _isFlashOn
                              ? Ionicons.flash
                              : Ionicons.flash_outline,
                          label: _isFlashOn ? '关闭闪光灯' : '打开闪光灯',
                          onTap: () {
                            setState(() {
                              _isFlashOn = !_isFlashOn;
                            });
                            _controller?.toggleFlash();
                          },
                        ),
                        const SizedBox(width: 32),
                        _buildActionButton(
                          icon: Ionicons.camera_reverse_outline,
                          label: '切换摄像头',
                          onTap: () {
                            _controller?.flipCamera();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 扫描动画线
          if (_isScanning)
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.width * 0.7,
                  child: const _ScannerLine(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha:0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && _isScanning) {
        setState(() {
          _isScanning = false;
        });
        controller.pauseCamera();
        
        // 返回扫描结果
        Get.back(result: scanData.code);
      }
    });
  }
}

/// 扫描动画线
class _ScannerLine extends StatefulWidget {
  const _ScannerLine();

  @override
  State<_ScannerLine> createState() => _ScannerLineState();
}

class _ScannerLineState extends State<_ScannerLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScannerLinePainter(
            progress: _animation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ScannerLinePainter extends CustomPainter {
  final double progress;

  _ScannerLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          AppTheme.primaryColor.withValues(alpha:0.8),
          AppTheme.primaryColor,
          AppTheme.primaryColor.withValues(alpha:0.8),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 4));

    final y = size.height * progress;
    
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
