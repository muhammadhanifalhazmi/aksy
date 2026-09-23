import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../features/pos/models/product.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

Future<Product?> showBarcodeScanner(
  BuildContext context, {
  required List<Product> products,
}) {
  return Navigator.of(context).push<Product>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BarcodeScannerScreen(products: products),
    ),
  );
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, required this.products});

  final List<Product> products;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const <BarcodeFormat>[],
  );

  bool _resolving = false;
  String? _status;

  Product? _resolve(String value) {
    final code = value.trim();
    if (code.isEmpty) return null;
    for (final product in widget.products) {
      if (product.barcode != null && product.barcode == code) return product;
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_resolving || !mounted) return;
    final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    final product = _resolve(code);
    if (product != null) {
      _resolving = true;
      Navigator.of(context).pop(product);
      return;
    }

    setState(() => _status = 'Barcode "$code" tidak ditemukan di katalog');
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted && _status != null) {
        setState(() => _status = null);
      }
    });
  }

  void _toggleTorch() {
    final state = _controller.value;
    if (!state.isRunning || state.torchState == TorchState.unavailable) return;
    _controller.toggleTorch();
  }

  void _switchCamera() => _controller.switchCamera();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;
                        final scanWindow = Rect.fromCenter(
                          center: Offset(width / 2, height / 2),
                          width: width * 0.78,
                          height: width * 0.52,
                        );
                        return MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          scanWindow: scanWindow,
                          errorBuilder: _buildCropped,
                          overlayBuilder: (_, boxConstraints) =>
                              ScanWindowOverlay(
                                controller: _controller,
                                scanWindow: scanWindow,
                                color: Colors.black.withValues(alpha: 0.55),
                                borderColor: AppTheme.primaryTeal,
                                borderWidth: 3,
                                borderRadius: BorderRadius.circular(16),
                              ),
                        );
                      },
                    ),
                  ),
                  if (_status != null)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 96,
                      child: _StatusBanner(message: _status!),
                    ),
                ],
              ),
            ),
            _buildBottomHint(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCropped(
    BuildContext context,
    MobileScannerException error,
  ) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(MobileScannerException error) {
    final message = error.errorCode.message;
    if (message.contains('permission') ||
        error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'Izin kamera ditolak. Izinkan akses kamera di pengaturan untuk '
          'memindai barcode.';
    }
    return 'Kamera tidak dapat dibuka.\n$message';
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Tutup',
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Scan Barcode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torch = state.torchState;
              return IconButton(
                onPressed: torch == TorchState.unavailable ? null : _toggleTorch,
                icon: Icon(
                  torch == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: torch == TorchState.unavailable
                      ? Colors.white24
                      : Colors.white,
                ),
                tooltip: 'Lampu senter',
              );
            },
          ),
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            tooltip: 'Ganti kamera',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHint(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: const Text(
        'Arahkan kamera ke barcode atau QR code produk',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String barcodePriceHint(Product product) {
  if (!product.hasWholesaleTier) return CurrencyFormatter.formatIDR(product.price);
  return '${CurrencyFormatter.formatIDR(product.price)} / '
      'grosir ${CurrencyFormatter.formatIDR(product.wholesalePrice!)} '
      'min ${product.minWholesaleQty}';
}