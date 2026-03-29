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
  AppState? _appState; // obtido uma vez no initState via contexto válido
  bool isPublic = true;

  @override
  void initState() {
    super.initState();
    // Obtemos o AppState aqui, onde o BuildContext ainda é parte do
    // widget tree correto (dentro do ChangeNotifierProvider<AppState>).
    // Não pode ser chamado diretamente em initState, por isso usamos
    // addPostFrameCallback que garante que o contexto está montado.
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

      // Simple validation for sefaz url (basic sanity check)
      if (url.toLowerCase().contains('http')) {
        // Garantia extra: se _appState ainda não foi inicializado
        // (ex: callback disparou antes do frame), tenta obtert agora.
        _appState ??= Provider.of<AppState>(context, listen: false);

        setState(() {
          isProcessing = true;
          processingMessage = 'Iniciando leitura...';
        });

        try {
          final success = await _appState!.processQrCode(
            url,
            isAvulsa: widget.isAvulsa,
            isPublic: isPublic,
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
              // Show dialog to force the user to see the error and prevent an infinite fast-scan loop
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
          // Captura erros que escapariam silenciosamente do callback async
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
      appBar: AppBar(
        title: const Text('Ler QR Code', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black54,
        actions: [
          Row(
            children: [
              Text(
                isPublic ? 'Público' : 'Privado',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Switch(
                value: isPublic,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.grey,
                onChanged: (val) {
                  setState(() {
                    isPublic = val;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),

          // Overlay overlay to guide user
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: MediaQuery.of(context).size.width * 0.7,
              ),
            ),
          ),

          if (isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      processingMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                      textAlign: TextAlign.center,
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

// Custom shape to draw the scanner transparent box
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
    this.overlayColor = 150, // Alpha
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
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(getOuterPath(rect), backgroundPaint);

    // Draw borders at the corners
    final rrect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    final topLeft = Offset(rrect.left, rrect.top);
    final topRight = Offset(rrect.right, rrect.top);
    final bottomLeft = Offset(rrect.left, rrect.bottom);
    final bottomRight = Offset(rrect.right, rrect.bottom);

    // Top-left
    canvas.drawLine(topLeft, topLeft + Offset(borderLength, 0), borderPaint);
    canvas.drawLine(topLeft, topLeft + Offset(0, borderLength), borderPaint);

    // Top-right
    canvas.drawLine(topRight, topRight + Offset(-borderLength, 0), borderPaint);
    canvas.drawLine(topRight, topRight + Offset(0, borderLength), borderPaint);

    // Bottom-left
    canvas.drawLine(
      bottomLeft,
      bottomLeft + Offset(borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      bottomLeft,
      bottomLeft + Offset(0, -borderLength),
      borderPaint,
    );

    // Bottom-right
    canvas.drawLine(
      bottomRight,
      bottomRight + Offset(-borderLength, 0),
      borderPaint,
    );
    canvas.drawLine(
      bottomRight,
      bottomRight + Offset(0, -borderLength),
      borderPaint,
    );
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
