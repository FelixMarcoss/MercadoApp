import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/app_state.dart';

class ProductChartModal extends StatefulWidget {
  final String productName;

  const ProductChartModal({super.key, required this.productName});

  @override
  State<ProductChartModal> createState() => _ProductChartModalState();
}

class _ProductChartModalState extends State<ProductChartModal> {
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;
  double minPrice = 0;
  double maxPrice = 0;
  String? currentImagePath;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final rawData = await appState.getProductHistory(widget.productName);

      List<Map<String, dynamic>> data = [];
      if (rawData.isNotEmpty) {
        // Data is already ASC ordered by date from the database
        data = rawData.toList();

        minPrice = data
            .map((e) => (e['unit_price'] as num).toDouble())
            .reduce((a, b) => a < b ? a : b);
        maxPrice = data
            .map((e) => (e['unit_price'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
      }

      if (mounted) {
        // Find the image path safely
        String? imagePath;
        try {
          if (appState.latestProducts.isNotEmpty) {
            final product = appState.latestProducts.firstWhere(
              (p) => p.name == widget.productName,
              orElse: () => appState.latestProducts.first,
            );
            if (product.name == widget.productName) {
              imagePath = product.imagePath;
            }
          }
        } catch (_) {}

        setState(() {
          history = data;
          currentImagePath = imagePath;
        });
      }
    } catch (e, st) {
      print('⚠️ Erro ao carregar histórico gráfico: $e');
      print(st);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        // Obter diretório de documentos do app
        final directory = await getApplicationDocumentsDirectory();
        
        // Obter extensão original
        final extension = image.path.split('.').last;
        
        // Criar nome de arquivo único para a imagem
        final fileName = 'p_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final savedImage = await File(image.path).copy('${directory.path}/$fileName');
        
        // Atualizar no banco de dados SQLite
        await DatabaseHelper.instance.updateProductImage(widget.productName, savedImage.path);
        
        // Atualizar listagem na AppState (precisa recarregar para a Home atualizar)
        if (mounted) {
           final appState = Provider.of<AppState>(context, listen: false);
           appState.loadProducts();
           
           // Disparar upload pra nuvem em background (não prendemos o UI aguardando)
           appState.uploadProductImage(widget.productName, savedImage);
        }

        setState(() {
          currentImagePath = savedImage.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao selecionar imagem: \$e')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Câmera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Padding(
      // Padding bottom for safe area + inset for chart
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    image: currentImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(currentImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: currentImagePath == null
                      ? const Icon(Icons.add_a_photo, color: Colors.grey, size: 30)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.productName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isLoading)
            const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (history.isEmpty || history.length == 1)
            SizedBox(
              height: 250,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.show_chart, size: 50, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      history.isEmpty
                          ? 'Histórico não encontrado.'
                          : 'Apenas 1 compra registrada.\nValor: ${currencyFormat.format(history.first['unit_price'])}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < history.length) {
                            DateTime date = DateTime.parse(
                              history[index]['date'],
                            );
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('dd/MM').format(date),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            currencyFormat
                                .format(value)
                                .replaceAll('R\$', '')
                                .trim(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                      left: BorderSide(color: Colors.grey.shade300),
                      top: const BorderSide(color: Colors.transparent),
                      right: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                  minX: 0,
                  maxX: (history.length - 1).toDouble(),
                  minY: minPrice * 0.9,
                  maxY: maxPrice * 1.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.asMap().entries.map((e) {
                        return FlSpot(
                          e.key.toDouble(),
                          e.value['unit_price'] as double,
                        );
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withAlpha(50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
