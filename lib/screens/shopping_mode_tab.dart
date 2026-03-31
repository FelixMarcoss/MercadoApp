import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/app_state.dart';
import '../widgets/product_chart_modal.dart';

class ShoppingModeTab extends StatefulWidget {
  const ShoppingModeTab({super.key});

  @override
  State<ShoppingModeTab> createState() => _ShoppingModeTabState();
}

class _ShoppingModeTabState extends State<ShoppingModeTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _addSuggestedItem(Product suggestion) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.addLiveCartItem(
      Product(
        id: -DateTime.now().millisecondsSinceEpoch, // Unique temp Id
        purchaseId: -1,
        name: suggestion.name,
        quantity: 1.0,
        unitType: suggestion.unitType,
        unitPrice: suggestion.unitPrice,
        totalPrice: suggestion.unitPrice,
        imagePath: suggestion.imagePath,
      ),
    );
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

  void _addNewCustomItem(String name) {
    final appState = Provider.of<AppState>(context, listen: false);
    final newItem = Product(
      id: -DateTime.now().millisecondsSinceEpoch,
      purchaseId: -1,
      name: name,
      quantity: 1.0,
      unitType: 'un',
      unitPrice: 0.0,
      totalPrice: 0.0,
    );
    appState.addLiveCartItem(newItem);
    _searchCtrl.clear();
    _searchFocus.unfocus();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _editPriceModal(newItem);
    });
  }

  void _clearCart() {
    Provider.of<AppState>(context, listen: false).clearLiveCart();
  }

  void _showHistoryModal(BuildContext context, String productName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ProductChartModal(
          productName: productName,
        );
      },
    );
  }

  void _editPriceModal(Product product) {
    final TextEditingController pc = TextEditingController(text: product.unitPrice.toStringAsFixed(2).replaceAll('.', ','));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Preço Histórico'),
        content: TextField(
          controller: pc,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
             prefixText: 'R\$ '
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
               final double newPrice = double.tryParse(pc.text.replaceAll(',', '.')) ?? product.unitPrice;
               Provider.of<AppState>(context, listen: false).updateLiveCartProductPrice(product, newPrice);
               Navigator.pop(ctx);
            }, 
            child: const Text('Salvar')
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final _liveCart = appState.liveCart;
    final double totalCart = appState.liveCartTotal;

    List<Product> suggestions = [];
    if (_query.isNotEmpty) {
      final Map<String, Product> uniqueProducts = {};
      for (var p in appState.latestProducts) {
        if (p.name.toLowerCase().contains(_query)) {
          uniqueProducts.putIfAbsent(p.name, () => p);
        }
      }
      suggestions = uniqueProducts.values.toList(); // Fixed logic based on uniqueness
    }

    return Column(
      children: [
        _buildHeader(),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEBEBEB),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              decoration: const InputDecoration(
                hintText: 'Pesquisar produto...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Color(0xFF757575)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Expanded(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                children: [
                  if (_query.isNotEmpty) ...[
                    const Text('Sugestões', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 10),
                    ...suggestions.map((s) => _buildSuggestionCard(s)).toList(),
                    _buildCustomAddCard(_query), // Adding custom item option
                    const Divider(height: 30),
                  ],

                  if (_liveCart.isEmpty && _query.isEmpty) 
                     Center(
                       child: Padding(
                         padding: const EdgeInsets.only(top: 80),
                         child: Column(
                           children: [
                             Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
                             const SizedBox(height: 16),
                             const Text('Carrinho vazio', style: TextStyle(color: Colors.grey, fontSize: 16)),
                           ],
                         ),
                       ),
                     )
                  else ..._liveCart.map((item) => _buildCartCard(item, appState)).toList()
                ],
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF8550),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
                  ),
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text('TOTAL PARCIAL', style: TextStyle(color: Color(0xFF88260E), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                           Text(
                             _currencyFormat.format(totalCart),
                             style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF330C02)),
                           )
                         ],
                       ),
                       ElevatedButton(
                         onPressed: _liveCart.isEmpty ? null : _clearCart,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFFAD2D06),
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                           elevation: 0
                         ),
                         child: const Row(
                           children: [
                             Text('Finalizar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             SizedBox(width: 8),
                             Icon(Icons.arrow_forward, size: 18)
                           ],
                         ),
                       )
                     ]
                  )
                )
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           const CircleAvatar(
             radius: 20,
             backgroundColor: Color(0xFFE0E0E0),
             child: Icon(Icons.person, color: Color(0xFF757575), size: 24),
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

  Widget _buildSuggestionCard(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF333333)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_currencyFormat.format(product.unitPrice), style: const TextStyle(color: Color(0xFF1E8267), fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
             onTap: () => _addSuggestedItem(product),
             child: Container(
               padding: const EdgeInsets.all(4),
               decoration: const BoxDecoration(
                  color: Color(0xFFAD2D06),
                  shape: BoxShape.circle
               ),
               child: const Icon(Icons.add, color: Colors.white, size: 20),
             ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomAddCard(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade400, width: 1.5), // replaced dashed
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adicionar novo item:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF333333)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
             onTap: () => _addNewCustomItem(name),
             child: Container(
               padding: const EdgeInsets.all(4),
               decoration: const BoxDecoration(
                  color: Color(0xFFAD2D06),
                  shape: BoxShape.circle
               ),
               child: const Icon(Icons.add, color: Colors.white, size: 20),
             ),
          )
        ],
      ),
    );
  }

  Widget _buildCartCard(Product item, AppState appState) {
    return Container(
       margin: const EdgeInsets.only(bottom: 16),
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
       ),
       child: Row(
          children: [
             Opacity( // Emulate the dark background of placeholder
               opacity: 0.9,
               child: ClipRRect(
                 borderRadius: BorderRadius.circular(16),
                 child: Container(
                   width: 70,
                   height: 70,
                   color: const Color(0xFF2B3A4A),
                   child: _buildProductImage(item.imagePath),
                 ),
               ),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Expanded(
                           child: Text(
                             item.name, 
                             style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF333333)),
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           )
                         ),
                         Column(
                           children: [
                              GestureDetector(
                                onTap: () => appState.removeLiveCartProduct(item),
                                child: const Icon(Icons.delete_outline, color: Color(0xFFD36C70), size: 20),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () => _showHistoryModal(context, item.name),
                                child: const Icon(Icons.show_chart, color: Colors.grey, size: 20),
                              )
                           ],
                         )
                       ],
                     ),
                     const SizedBox(height: 8),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                             decoration: BoxDecoration(
                               color: const Color(0xFFF0F0F0),
                               borderRadius: BorderRadius.circular(20)
                             ),
                             child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => appState.updateLiveCartProductQuantity(item, -1),
                                    child: const Icon(Icons.remove, size: 16, color: Color(0xFF333333))
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => appState.updateLiveCartProductQuantity(item, 1),
                                    child: const Icon(Icons.add, size: 16, color: Color(0xFF333333))
                                  ),
                                ],
                             ),
                          ),
                          GestureDetector(
                            onTap: () => _editPriceModal(item),
                            child: Text(
                              _currencyFormat.format(item.totalPrice),
                              style: const TextStyle(color: Color(0xFF1E8267), fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          )
                       ],
                     )
                  ],
               ),
             )
          ],
       )
    );
  }

  Widget _buildProductImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return const Icon(Icons.shopping_bag, color: Colors.white, size: 30);
  }
}
