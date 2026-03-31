import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_state.dart';
import '../providers/auth_state.dart';
import '../models/product.dart';
import '../widgets/product_chart_modal.dart';
import 'scanner_screen.dart';
import 'shopping_mode_tab.dart';
import '../database/database_helper.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_currentIndex == 3) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getMonthName(int month) {
    const months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      drawer: _buildDrawer(context),
      appBar: (_currentIndex == 0 || _currentIndex == 2) ? null : _buildAppBar(),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (appState.errorMessage.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(appState.errorMessage), backgroundColor: Colors.red),
              );
            });
          }

          return SafeArea(
            child: Column(
              children: [
                if (appState.syncMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      appState.syncMessage,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(child: _buildBody(appState)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF7F7F7),
      elevation: 0,
      scrolledUnderElevation: 1,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Pesquisar...',
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            )
          : Text(
              _currentIndex == 2 ? 'Carrinho' : 'Histórico',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _isSearching = false;
                _searchQuery = '';
                _searchController.clear();
              } else {
                _isSearching = true;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildBody(AppState appState) {
    if (_currentIndex == 0) {
      return _buildDashboard(appState);
    } else if (_currentIndex == 2) {
      return const ShoppingModeTab();
    } else if (_currentIndex == 3) {
      return _buildHistoryTabbedView(appState);
    }
    return const SizedBox.shrink();
  }

  Widget _buildDashboard(AppState appState) {
    final DateTime now = DateTime.now();
    final targetMonth = appState.selectedMonth ?? now.month;
    final targetYear = appState.selectedYear ?? now.year;

    final currentMonthItems = appState.latestProducts.where((p) {
      if (p.isAvulsa) return false;
      if (p.date == null) return false;
      try {
        final d = DateTime.parse(p.date!);
        return d.month == targetMonth && d.year == targetYear;
      } catch (_) {
        return false;
      }
    }).toList();

    List<Product> filteredMonth = currentMonthItems;
    if (_searchQuery.isNotEmpty) {
      filteredMonth = filteredMonth.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
    }

    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return RefreshIndicator(
      onRefresh: () async {
        Provider.of<AppState>(context, listen: false).forceSyncDown();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(context),
            _buildSummaryCard(appState),
            _buildActionButtons(),
            _buildRecentPurchases(filteredMonth, currencyFormat),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFE0E0E0),
                  child: Icon(Icons.person, color: Color(0xFF757575), size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BEM-VINDO', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  Text(
                    '${_getMonthName(now.month)} ${now.year}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                  ),
                ],
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.notifications, color: Color(0xFFE96E4C), size: 28),
            onSelected: (val) async {
              if (val == 'refresh') {
                Provider.of<AppState>(context, listen: false).forceSyncDown();
              } else if (val == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Limpar dados'),
                    content: const Text('Isso irá apagar TODOS os produtos e compras. Prosseguir?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await Provider.of<AppState>(context, listen: false).clearAllData();
                }
              } else if (val == 'search') {
                setState(() {
                  _isSearching = true;
                  // Searching on dashboard will be less visible without app bar
                  // Usually search here redirects to History or opens a search overlay. We'll rely on History for searching.
                  _currentIndex = 3;
                });
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'search', child: Text('🔍 Pesquisar')),
              PopupMenuItem(value: 'refresh', child: Text('🔄 Atualizar Dados')),
              PopupMenuItem(value: 'clear', child: Text('🗑️ Limpar todos os dados')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(AppState appState) {
    final double totalP = appState.monthlyTotal;
    final limit = appState.spendingLimit;
    final percentage = limit > 0 ? (totalP / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = limit > 0 ? (limit - totalP) : 0.0;
    
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showMonthSelector(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCE522B), Color(0xFFF9876C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD64D24).withAlpha(80),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Gasto', style: TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(totalP),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'META: ${currencyFormat.format(limit).replaceAll('R\$', 'R\$ ')}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.white.withAlpha(50),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 8,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${(percentage * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.0)),
                            const Text('USADO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: limit > 0 && remaining >= 0
              ? RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF555555), fontSize: 15, fontStyle: FontStyle.italic),
                    children: [
                      const TextSpan(text: 'Você ainda tem '),
                      TextSpan(text: currencyFormat.format(remaining), style: const TextStyle(color: Color(0xFF197959), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
                      const TextSpan(text: ' disponíveis para este mês.'),
                    ],
                  ),
                )
              : RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xFF555555), fontSize: 15, fontStyle: FontStyle.italic),
                    children: [
                       const TextSpan(text: 'Você ultrapassou sua meta em '),
                       TextSpan(text: currencyFormat.format(totalP - limit), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal)),
                    ]
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                final appState = Provider.of<AppState>(context, listen: false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangeNotifierProvider.value(value: appState, child: const ScannerScreen(isAvulsa: false))),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Color(0xFF81F9E3), shape: BoxShape.circle),
                      child: const Icon(Icons.qr_code_scanner, color: Color(0xFF1B6A56), size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text('Escanear QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentIndex = 3);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(color: Color(0xFFFFE8E0), shape: BoxShape.circle),
                      child: const Icon(Icons.history, color: Color(0xFFD64D24), size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text('Ver Histórico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPurchases(List<Product> products, NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Últimas Compras', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 3),
                child: const Text('VER TUDO', style: TextStyle(color: Color(0xFFB52323), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
              )
            ],
          ),
        ),
        if (products.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 20),
             child: Center(child: Text('Nenhuma compra recente encontrada.', style: TextStyle(color: Colors.grey))),
           )
        else
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length > 5 ? 5 : products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index], currencyFormat);
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHistoryTabbedView(AppState appState) {
    final DateTime now = DateTime.now();
    final targetMonth = appState.selectedMonth ?? now.month;
    final targetYear = appState.selectedYear ?? now.year;

    final currentMonthItems = appState.latestProducts.where((p) {
      if (p.isAvulsa) return false;
      if (p.date == null) return false;
      try {
        final d = DateTime.parse(p.date!);
        return d.month == targetMonth && d.year == targetYear;
      } catch (_) {
        return false;
      }
    }).toList();

    final avulsaItems = appState.latestProducts.where((p) => p.isAvulsa).toList();

    List<Product> filteredLatest = appState.latestProducts;
    List<Product> filteredMonth = currentMonthItems;
    List<Product> filteredAvulsa = avulsaItems;

    if (_searchQuery.isNotEmpty) {
      filteredLatest = filteredLatest.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
      filteredMonth = filteredMonth.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
      filteredAvulsa = filteredAvulsa.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
    }

    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE96E4C),
          labelColor: const Color(0xFFE96E4C),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'Todos'), Tab(text: 'Mês'), Tab(text: 'Avulsa')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductList(filteredLatest, currencyFormat),
              _buildProductList(filteredMonth, currencyFormat),
              _buildProductList(filteredAvulsa, currencyFormat),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductList(List<Product> products, NumberFormat currencyFormat) {
    if (products.isEmpty) {
      return const Center(child: Text('Nenhum produto cadastrado.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80, left: 20, right: 20),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductCard(products[index], currencyFormat),
    );
  }

  Widget _buildProductCard(Product product, NumberFormat currencyFormat) {
    final currentImagePath = product.imagePath;

    String purchaseDateStr = 'Data desc.';
    if (product.date != null) {
      try {
        final d = DateTime.parse(product.date!);
        purchaseDateStr = '${d.day} de ${_getMonthName(d.month)}, ${d.year}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        final appState = Provider.of<AppState>(context, listen: false);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => ChangeNotifierProvider.value(
            value: appState,
            child: ProductChartModal(productName: product.name),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: (currentImagePath == null || !(File(currentImagePath).existsSync()))
                  ? const Center(child: Icon(Icons.shopping_bag, color: Color(0xFF9AA0A6), size: 28))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(currentImagePath),
                        fit: BoxFit.cover,
                        width: 52,
                        height: 52,
                        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.shopping_bag, color: Color(0xFF9AA0A6))),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF333333)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    purchaseDateStr,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(product.unitPrice),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.isAvulsa ? const Color(0xFFE0E0E0) : const Color(0xFF81F9E3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.isAvulsa ? 'OCASIONAL' : 'COMPRA DO MÊS',
                    style: TextStyle(
                      color: product.isAvulsa ? const Color(0xFF555555) : const Color(0xFF1B6A56),
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 1) {
              final appState = Provider.of<AppState>(context, listen: false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChangeNotifierProvider.value(value: appState, child: const ScannerScreen(isAvulsa: false))),
              );
            } else {
              setState(() => _currentIndex = index);
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

  void _showMonthSelector(BuildContext context) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final monthlyTotals = await DatabaseHelper.instance.getMonthlyTotalsList();
    if (!context.mounted) return;

    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Selecione um Arquivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFFD64D24)),
                title: const Text('Voltar para o Mês Atual', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: appState.isViewingArchive ? null : const Icon(Icons.check, color: Color(0xFFD64D24)),
                onTap: () {
                  appState.setSelectedMonth(null, null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              if (monthlyTotals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('Nenhum histórico encontrado.', style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: monthlyTotals.length,
                    itemBuilder: (context, index) {
                      final item = monthlyTotals[index];
                      final String monthYear = item['month_year'] as String;
                      final double total = (item['total'] as num).toDouble();
                      final parts = monthYear.split('-');
                      if (parts.length != 2) return const SizedBox.shrink();
                      final int year = int.parse(parts[0]);
                      final int month = int.parse(parts[1]);
                      final bool isSelected = appState.selectedMonth == month && appState.selectedYear == year;

                      return ListTile(
                        leading: Icon(Icons.history, color: isSelected ? const Color(0xFFD64D24) : Colors.grey),
                        title: Text('$month/$year', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text('Gasto: ${currencyFormat.format(total)}'),
                        trailing: isSelected ? const Icon(Icons.check, color: Color(0xFFD64D24)) : null,
                        onTap: () {
                          appState.setSelectedMonth(month, year);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Consumer2<AppState, AuthState>(
        builder: (context, appState, authState, child) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFCE522B), Color(0xFFF9876C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withAlpha(50),
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      authState.userEmail ?? 'Usuário',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('MercadoApp', style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFFD64D24)),
                title: const Text('Configurações de Meta'),
                subtitle: const Text('Defina seu limite de gastos mensal'),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsDialog(context, appState);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sair', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await authState.logout();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, AppState appState) {
    final TextEditingController limitController = TextEditingController(text: appState.spendingLimit.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Meta de Gastos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Defina um valor máximo desejado para suas compras no mês.', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Limite Mensal (R\$)', border: OutlineInputBorder(), prefixText: 'R\$ '),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final double? newLimit = double.tryParse(limitController.text.replaceAll(',', '.'));
                if (newLimit != null && newLimit > 0) {
                  appState.setSpendingLimit(newLimit);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Salvar Meta'),
            ),
          ],
        );
      },
    );
  }
}
