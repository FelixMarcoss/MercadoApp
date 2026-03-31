import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class ScannerScreen extends StatefulWidget {
  final bool isAvulsa;
  const ScannerScreen({super.key, this.isAvulsa = false});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool isProcessing = false;
  String processingMessage = 'Processando...';
  AppState? _appState;
  late bool _isAvulsa;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _isAvulsa = widget.isAvulsa;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _appState = Provider.of<AppState>(context, listen: false);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    print('🔍 onDetect fired: ${capture.barcodes.length} barcodes');
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String url = barcodes.first.rawValue!;

      if (url.toLowerCase().contains('http')) {
        _appState ??= Provider.of<AppState>(context, listen: false);

        setState(() {
          isProcessing = true;
          processingMessage = 'Iniciando leitura...';
        });

        try {
          final success = await _appState!.processQrCode(
            url,
            isAvulsa: _isAvulsa,
            isPublic: true,
            onStatus: (msg) {
              if (mounted) {
                setState(() {
                  processingMessage = msg;
                });
              }
            },
          );

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nota processada com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context); // go back to home
            } else {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('Erro na Leitura'),
                  content: Text(_appState!.errorMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tentar Novamente'),
                    ),
                  ],
                ),
              );

              if (mounted) {
                setState(() {
                  isProcessing = false;
                });
              }
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() { isProcessing = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro inesperado: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code inválido (não é uma URL).')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(controller: controller, onDetect: _onDetect),
                  
                  // Camera Overlay
                  Container(
                    decoration: ShapeDecoration(
                      shape: QrScannerOverlayShape(
                        borderColor: const Color(0xFFD64D24), // Orange like design
                        borderRadius: 16,
                        borderLength: 40,
                        borderWidth: 4,
                        cutOutSize: MediaQuery.of(context).size.width * 0.75,
                      ),
                    ),
                  ),

                  // Flashlight Button
                  Positioned(
                    top: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: () {
                        controller.toggleTorch();
                        setState(() {
                           _isTorchOn = !_isTorchOn;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flashlight_on, // Fixed icon
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  if (isProcessing)
                    Container(
                      color: Colors.black.withAlpha(200),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFFD64D24)),
                            const SizedBox(height: 16),
                            Text(
                              processingMessage,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomSheet(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           GestureDetector(
             onTap: () => Navigator.pop(context), // Acts as back button implicitly since it's pushed
             child: const CircleAvatar(
               radius: 20,
               backgroundColor: Color(0xFFE0E0E0),
               child: Icon(Icons.person, color: Color(0xFF757575), size: 24),
             ),
           ),
           const Text(
             'MercadoApp',
             style: TextStyle(
                color: Color(0xFFD64D24), 
                fontSize: 22, 
                fontWeight: FontWeight.w900, 
                fontStyle: FontStyle.italic,
             ),
           ),
           const Icon(Icons.notifications, color: Colors.grey, size: 28),
        ],
      )
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E2E2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                     'Tipo de Compra', 
                     style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF333333)),
                   ),
                   const SizedBox(height: 4),
                   const Text(
                     'Categorize seu gasto automaticamente', 
                     style: TextStyle(color: Color(0xFF757575), fontSize: 13),
                   ),
                ],
              ),
              const Icon(Icons.category, color: Color(0xFFD64D24)),
            ],
          ),
          const SizedBox(height: 24),
          // Segmented Control
          Container(
             padding: const EdgeInsets.all(4),
             decoration: BoxDecoration(
               color: const Color(0xFFF5F5F5),
               borderRadius: BorderRadius.circular(30),
             ),
             child: Row(
                children: [
                   Expanded(
                     child: GestureDetector(
                       onTap: () => setState(() => _isAvulsa = false),
                       child: Container(
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         decoration: BoxDecoration(
                           color: !_isAvulsa ? const Color(0xFFB93315) : Colors.transparent,
                           borderRadius: BorderRadius.circular(26),
                         ),
                         child: Center(
                           child: Text(
                             'Compra do Mês',
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               color: !_isAvulsa ? Colors.white : const Color(0xFF757575),
                             ),
                           ),
                         ),
                       ),
                     ),
                   ),
                   Expanded(
                     child: GestureDetector(
                       onTap: () => setState(() => _isAvulsa = true),
                       child: Container(
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         decoration: BoxDecoration(
                           color: _isAvulsa ? const Color(0xFFB93315) : Colors.transparent,
                           borderRadius: BorderRadius.circular(26),
                         ),
                         child: Center(
                           child: Text(
                             'Ocasional',
                             style: TextStyle(
                               fontWeight: FontWeight.bold,
                               color: _isAvulsa ? Colors.white : const Color(0xFF757575),
                             ),
                           ),
                         ),
                       ),
                     ),
                   ),
                ],
             ),
          ),
        ],
      )
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
             color: Colors.black.withAlpha(10),
             blurRadius: 20,
             offset: const Offset(0, -5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomNavigationBar(
          currentIndex: 1, // Fix on scanner
          onTap: (index) {
            if (index != 1) {
               // Popping the scanner screen automatically goes back to the home screen
               Navigator.pop(context);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFD64D24),
          unselectedItemColor: const Color(0xFF9E9E9E),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, height: 1.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, height: 1.5),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 26), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner, size: 26), label: 'SCAN'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart, size: 26), label: 'CART'),
            BottomNavigationBarItem(icon: Icon(Icons.history, size: 26), label: 'HISTORY'),
          ],
        ),
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final double overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = 150,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path();
    path.addRect(rect);
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
        Radius.circular(borderRadius),
      ),
    );
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withAlpha(150)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(getOuterPath(rect), backgroundPaint);

    final rrect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    // Using drawArc and drawLine to draw rounded corner reticles
    // Top-Left
    canvas.drawArc(
        Rect.fromCircle(center: Offset(rrect.left + borderRadius, rrect.top + borderRadius), radius: borderRadius),
        -3.14159, 1.5708, false, borderPaint);
    canvas.drawLine(Offset(rrect.left, rrect.top + borderRadius), Offset(rrect.left, rrect.top + borderLength), borderPaint);
    canvas.drawLine(Offset(rrect.left + borderRadius, rrect.top), Offset(rrect.left + borderLength, rrect.top), borderPaint);

    // Top-Right
    canvas.drawArc(
        Rect.fromCircle(center: Offset(rrect.right - borderRadius, rrect.top + borderRadius), radius: borderRadius),
        -1.5708, 1.5708, false, borderPaint);
    canvas.drawLine(Offset(rrect.right, rrect.top + borderRadius), Offset(rrect.right, rrect.top + borderLength), borderPaint);
    canvas.drawLine(Offset(rrect.right - borderRadius, rrect.top), Offset(rrect.right - borderLength, rrect.top), borderPaint);

    // Bottom-Left
    canvas.drawArc(
        Rect.fromCircle(center: Offset(rrect.left + borderRadius, rrect.bottom - borderRadius), radius: borderRadius),
        1.5708, 1.5708, false, borderPaint);
    canvas.drawLine(Offset(rrect.left, rrect.bottom - borderRadius), Offset(rrect.left, rrect.bottom - borderLength), borderPaint);
    canvas.drawLine(Offset(rrect.left + borderRadius, rrect.bottom), Offset(rrect.left + borderLength, rrect.bottom), borderPaint);

    // Bottom-Right
    canvas.drawArc(
        Rect.fromCircle(center: Offset(rrect.right - borderRadius, rrect.bottom - borderRadius), radius: borderRadius),
        0, 1.5708, false, borderPaint);
    canvas.drawLine(Offset(rrect.right, rrect.bottom - borderRadius), Offset(rrect.right, rrect.bottom - borderLength), borderPaint);
    canvas.drawLine(Offset(rrect.right - borderRadius, rrect.bottom), Offset(rrect.right - borderLength, rrect.bottom), borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
