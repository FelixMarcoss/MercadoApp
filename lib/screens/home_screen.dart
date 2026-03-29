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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final NumberFormat currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Pesquisar...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: colorScheme.onSurface.withAlpha(150)),
                ),
                style: TextStyle(color: colorScheme.onSurface),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : Text(
                'Minhas Compras',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
            onPressed: () {
              Provider.of<AppState>(context, listen: false).forceSyncDown();
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: colorScheme.onSurfaceVariant),
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            onSelected: (value) async {
              if (value == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Limpar dados'),
                    content: const Text(
                      'Isso irá apagar TODOS os produtos e compras. Prosseguir?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Apagar',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await Provider.of<AppState>(
                    context,
                    listen: false,
                  ).clearAllData();
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('🗑️ Limpar todos os dados'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          if (appState.errorMessage.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(appState.errorMessage),
                  backgroundColor: colorScheme.error,
                ),
              );
            });
          }

          final bool isLiveTab = _tabController.index == 3;
          final double totalP =
              isLiveTab ? appState.liveCartTotal : appState.monthlyTotal;

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

          final avulsaItems = appState.latestProducts
              .where((p) => p.isAvulsa)
              .toList();

          List<Product> filteredLatest = appState.latestProducts;
          List<Product> filteredMonth = currentMonthItems;
          List<Product> filteredAvulsa = avulsaItems;

          if (_searchQuery.isNotEmpty) {
            filteredLatest = filteredLatest.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
            filteredMonth = filteredMonth.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
            filteredAvulsa = filteredAvulsa.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
          }

          return Column(
            children: [
              if (appState.syncMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    appState.syncMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Summary card (tappable to select month)
              GestureDetector(
                onTap: isLiveTab ? null : () => _showMonthSelector(context),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          _getCardGradientColors(totalP, appState.spendingLimit),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _getCardShadowColor(totalP, appState.spendingLimit)
                            .withAlpha(100),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isLiveTab
                                ? 'CARRINHO'
                                : (appState.isViewingArchive
                                    ? 'MÊS: ${appState.selectedMonth.toString().padLeft(2, '0')}/${appState.selectedYear}'
                                    : 'GASTO DESTE MÊS'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (!isLiveTab)
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white70,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'R\$ ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            currencyFormat
                                .format(totalP)
                                .replaceAll('R\$', '')
                                .trim(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!isLiveTab)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.data_usage,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${((totalP / appState.spendingLimit) * 100).toStringAsFixed(1)}% do limite de ${currencyFormat.format(appState.spendingLimit)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // TabBar
              TabBar(
                controller: _tabController,
                indicatorColor: colorScheme.primary,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Todos'),
                  Tab(text: 'Mês'),
                  Tab(text: 'Avulsa'),
                  Tab(text: 'Carrinho'),
                ],
              ),
              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductList(filteredLatest, currencyFormat),
                    _buildProductList(filteredMonth, currencyFormat),
                    _buildProductList(filteredAvulsa, currencyFormat),
                    ShoppingModeTab(searchQuery: _searchQuery),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _tabController.index == 3
          ? null // Hide FAB in "Carrinho" mode
          : FloatingActionButton(
              onPressed: () {
                final isAvulsa = _tabController.index == 2;
                final appState = Provider.of<AppState>(context, listen: false);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangeNotifierProvider.value(
                      value: appState,
                      child: ScannerScreen(isAvulsa: isAvulsa),
                    ),
                  ),
                );
              },
              backgroundColor: _tabController.index == 2
                  ? Theme.of(context).colorScheme.secondary
                  : Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
            ),
    );
  }

  Widget _buildProductList(
    List<Product> products,
    NumberFormat currencyFormat,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum produto cadastrado.',
              style: TextStyle(fontSize: 16, color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80, left: 16, right: 16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final currentImagePath = product.imagePath;

        String purchaseDateStr = 'Data desc.';
        if (product.date != null) {
          try {
            final d = DateTime.parse(product.date!);
            final now = DateTime.now();
            final difference = DateTime(
              now.year,
              now.month,
              now.day,
            ).difference(DateTime(d.year, d.month, d.day)).inDays;

            if (difference == 0) {
              purchaseDateStr = 'Hoje, ${DateFormat('HH:mm').format(d)}';
            } else if (difference == 1) {
              purchaseDateStr = 'Ontem, ${DateFormat('HH:mm').format(d)}';
            } else {
              purchaseDateStr = '$difference dias atrás';
            }
          } catch (_) {}
        }

        return GestureDetector(
          onTap: () {
            final appState = Provider.of<AppState>(context, listen: false);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => ChangeNotifierProvider.value(
                value: appState,
                child: ProductChartModal(productName: product.name),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(10),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: currentImagePath == null
                      ? Center(
                          child: Icon(
                            Icons.image,
                            color: colorScheme.outline,
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(currentImagePath),
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(product.unitPrice),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            purchaseDateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: product.isAvulsa
                        ? colorScheme.secondaryContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.isAvulsa ? 'AVULSA' : 'MÊS',
                    style: TextStyle(
                      color: product.isAvulsa
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMonthSelector(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = Provider.of<AppState>(context, listen: false);
    final monthlyTotals = await DatabaseHelper.instance.getMonthlyTotalsList();

    if (!context.mounted) return;

    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Selecione um Arquivo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: Icon(Icons.calendar_today, color: colorScheme.primary),
                title: const Text(
                  'Voltar para o Mês Atual',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: appState.isViewingArchive
                    ? null
                    : Icon(Icons.check, color: colorScheme.primary),
                onTap: () {
                  appState.setSelectedMonth(null, null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              if (monthlyTotals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Nenhum histórico encontrado.',
                    style: TextStyle(color: colorScheme.outline),
                  ),
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

                      final bool isSelected = appState.selectedMonth == month &&
                          appState.selectedYear == year;

                      return ListTile(
                        leading: Icon(
                          Icons.history,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline,
                        ),
                        title: Text(
                          '$month/$year',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle:
                            Text('Gasto: ${currencyFormat.format(total)}'),
                        trailing: isSelected
                            ? Icon(Icons.check, color: colorScheme.primary)
                            : null,
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

  List<Color> _getCardGradientColors(double total, double limit) {
    if (limit <= 0) {
      return [Colors.teal.shade400, Colors.teal.shade600];
    }

    final double percentage = total / limit;

    if (percentage < 0.75) {
      // Comfort Zone — green
      return [Colors.teal.shade400, Colors.teal.shade600];
    } else if (percentage < 1.0) {
      // Alert Zone — orange
      return [Colors.orange.shade400, Colors.orange.shade600];
    } else {
      // Danger Zone — red
      return [Colors.red.shade600, Colors.red.shade800];
    }
  }

  Color _getCardShadowColor(double total, double limit) {
    if (limit <= 0) return Colors.teal;

    final double percentage = total / limit;

    if (percentage < 0.75) return Colors.teal;
    if (percentage < 1.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDrawer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: Consumer2<AppState, AuthState>(
        builder: (context, appState, authState, child) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primaryContainer,
                    ],
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
                      backgroundColor: colorScheme.onPrimary.withAlpha(40),
                      child: Icon(
                        Icons.person,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      authState.userEmail ?? 'Usuário',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MercadoApp',
                      style: TextStyle(
                        color: colorScheme.onPrimary.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.settings, color: colorScheme.primary),
                title: const Text('Configurações de Meta'),
                subtitle: const Text('Defina seu limite de gastos mensal'),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsDialog(context, appState);
                },
              ),

              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: colorScheme.error),
                title: Text(
                  'Sair',
                  style: TextStyle(color: colorScheme.error),
                ),
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
    final TextEditingController limitController = TextEditingController(
      text: appState.spendingLimit.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Meta de Gastos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Defina um valor máximo desejado para suas compras no mês. O card na tela inicial mudará de cor conforme você se aproxima desse limite.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limite Mensal (R\$)',
                  border: OutlineInputBorder(),
                  prefixText: 'R\$ ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final double? newLimit = double.tryParse(
                  limitController.text.replaceAll(',', '.'),
                );
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
