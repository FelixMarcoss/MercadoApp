import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../services/scraping_service.dart';
import '../services/pocketbase_service.dart';

/// Application-level state shared across all screens.
///
/// Now scoped to a specific authenticated [userId]. Pass the
/// new [userId] whenever the user logs in (or changes account).
class AppState extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ScrapingService _scrapingService = ScrapingService();
  late final PocketBaseService _pocketBaseService;

  final String userId;

  List<Product> _latestProducts = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _syncMessage = '';
  double _monthlyTotal = 0.0;

  // Archive Selection State
  int? _selectedMonth;
  int? _selectedYear;

  // Spending Limit
  double _spendingLimit = 1000.0;

  // Live Cart State
  final List<Product> _liveCart = [];

  List<Product> get latestProducts => _latestProducts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get syncMessage => _syncMessage;
  double get monthlyTotal => _monthlyTotal;

  int? get selectedMonth => _selectedMonth;
  int? get selectedYear => _selectedYear;
  bool get isViewingArchive =>
      _selectedMonth != null && _selectedYear != null;
  double get spendingLimit => _spendingLimit;

  List<Product> get liveCart => _liveCart;
  double get liveCartTotal =>
      _liveCart.fold(0.0, (sum, p) => sum + p.totalPrice);

  AppState({required this.userId, required PocketBase pb}) {
    _pocketBaseService = PocketBaseService(pb);
    loadProducts().then((_) => syncWithCloud());
  }

  String get _householdId {
    try {
      final model = _pocketBaseService.pb.authStore.model;
      if (model != null && model is RecordModel) {
        return model.getStringValue('household_id');
      }
    } catch (_) {}
    return '';
  }

  String get userCode => userId;
  String get currentHouseholdId => _householdId.isNotEmpty ? _householdId : userId;

  // ─── Live cart ──────────────────────────────────────────────────────

  void addLiveCartItem(Product product) {
    _liveCart.add(product);
    notifyListeners();
  }

  void removeLiveCartItem(int index) {
    _liveCart.removeAt(index);
    notifyListeners();
  }

  void removeLiveCartProduct(Product product) {
    _liveCart.remove(product);
    notifyListeners();
  }

  void updateLiveCartProductQuantity(Product product, double delta) {
    final index = _liveCart.indexOf(product);
    if (index != -1) {
      final newQty = product.quantity + delta;
      if (newQty <= 0) {
        _liveCart.removeAt(index);
      } else {
        _liveCart[index] = Product(
          id: product.id,
          purchaseId: product.purchaseId,
          name: product.name,
          quantity: newQty,
          unitType: product.unitType,
          unitPrice: product.unitPrice,
          totalPrice: newQty * product.unitPrice,
          isAvulsa: product.isAvulsa,
          imagePath: product.imagePath,
          date: product.date,
        );
      }
      notifyListeners();
    }
  }

  void updateLiveCartProductPrice(Product product, double newPrice) {
    final index = _liveCart.indexOf(product);
    if (index != -1) {
      _liveCart[index] = Product(
        id: product.id,
        purchaseId: product.purchaseId,
        name: product.name,
        quantity: product.quantity,
        unitType: product.unitType,
        unitPrice: newPrice,
        totalPrice: product.quantity * newPrice,
        isAvulsa: product.isAvulsa,
        imagePath: product.imagePath,
        date: product.date,
      );
      notifyListeners();
    }
  }

  void clearLiveCart() {
    _liveCart.clear();
    notifyListeners();
  }

  // ─── Selection / Settings ────────────────────────────────────────────

  void setSelectedMonth(int? month, int? year) {
    _selectedMonth = month;
    _selectedYear = year;
    loadProducts();
  }

  Future<void> setSpendingLimit(double limit) async {
    _spendingLimit = limit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('spending_limit', limit);
    notifyListeners();
  }

  // ─── Core data loading ───────────────────────────────────────────────

  Future<void> loadProducts({bool skipSync = false}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _spendingLimit = prefs.getDouble('spending_limit') ?? 1000.0;

      final now = DateTime.now();
      final targetMonth = _selectedMonth ?? now.month;
      final targetYear = _selectedYear ?? now.year;

      _latestProducts = await _dbHelper.getLatestProducts(
          month: targetMonth, year: targetYear);
      _monthlyTotal =
          await _dbHelper.getMonthlyTotal(targetMonth, targetYear);

      // Seed from cloud on first launch (empty local db)
      if (!skipSync && _latestProducts.isEmpty && !isViewingArchive) {
        await _syncDownIfEmpty();
        _latestProducts = await _dbHelper.getLatestProducts(
            month: targetMonth, year: targetYear);
        _monthlyTotal =
            await _dbHelper.getMonthlyTotal(targetMonth, targetYear);
      }
    } catch (e) {
      _errorMessage = 'Falha ao carregar produtos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncDownIfEmpty() async {
    _syncMessage = '📥 Baixando dados da nuvem...';
    notifyListeners();

    try {
      final records =
          await _pocketBaseService.fetchAllProducts(userId, householdId: currentHouseholdId);
      if (records.isEmpty) {
        _syncMessage = 'Nenhum dado encontrado ($currentHouseholdId)';
        return;
      }

      // Group records by purchase date to reconstruct individual purchases
      final Map<String, List<Map<String, dynamic>>> groupedRecords = {};
      for (var r in records) {
        final String ultimaCompra = r['ultima_compra']?.toString() ?? '';
        final String created = r['created']?.toString() ?? '';
        final purchaseKey = ultimaCompra.isNotEmpty
            ? ultimaCompra
            : (created.isNotEmpty
                ? created
                : DateTime.now().toIso8601String());
        groupedRecords.putIfAbsent(purchaseKey, () => []).add(r);
      }

      final List<int> savedPurchaseIds = [];

      for (var entry in groupedRecords.entries) {
        final dateStr = entry.key;
        final items = entry.value;

        List<Product> productsToSave = [];
        double totalVal = 0.0;

        for (var r in items) {
          final double price =
              (r['preco_medio'] is num) ? (r['preco_medio'] as num).toDouble() : 0.0;
          final double qty =
              (r['quantidade'] is num) ? (r['quantidade'] as num).toDouble() : 1.0;
          final double totalPrice = price * qty;
          totalVal += totalPrice;

          final String prodName = r['produto']?.toString() ?? '';
          final String unit = r['unidade']?.toString() ?? '';
          final bool isAvulsa = r['avulsa'] == true;
          final String recordId = r['id']?.toString() ?? '';
          final String collectionId = r['collectionId']?.toString() ?? '';
          final String fotoName = r['fotos']?.toString() ?? '';

          String? localImagePath;
          if (fotoName.isNotEmpty &&
              recordId.isNotEmpty &&
              collectionId.isNotEmpty) {
            try {
              final url =
                  'https://telemetria.minacon.com.br/api/files/$collectionId/$recordId/$fotoName';
              final directory = await getApplicationDocumentsDirectory();
              final savedImageFile =
                  File('${directory.path}/$fotoName');
              if (!await savedImageFile.exists()) {
                final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
                if (response.statusCode == 200) {
                  await savedImageFile.writeAsBytes(response.bodyBytes);
                  localImagePath = savedImageFile.path;
                }
              } else {
                localImagePath = savedImageFile.path;
              }
            } catch (_) {}
          }

          productsToSave.add(Product(
            purchaseId: 0,
            name: prodName.isNotEmpty ? prodName : 'Produto',
            quantity: qty,
            unitType: unit.isNotEmpty ? unit : 'un',
            unitPrice: price,
            totalPrice: totalPrice,
            isAvulsa: isAvulsa,
            imagePath: localImagePath,
          ));
        }

        bool anyPublic = items.any((r) => (r['household_id']?.toString() ?? '').isNotEmpty);

        final purchase = Purchase(
          date: dateStr,
          totalValue: totalVal,
          url: 'sync_pb_$dateStr',
          isAvulsa: false,
          isPublic: anyPublic,
        );

        try {
          final insertedId =
              await _dbHelper.insertPurchaseTransaction(purchase, productsToSave);
          savedPurchaseIds.add(insertedId);
        } catch (e) {
          // Ignora se o url já existe (já baixado)
        }
      }

      if (savedPurchaseIds.isNotEmpty) {
        await _dbHelper.markPurchasesAsSynced(savedPurchaseIds);
      }

      _syncMessage = '✅ Dados baixados com sucesso.';
    } catch (e) {
      _syncMessage = '❌ Erro ao baixar dados: $e';
    }
    notifyListeners();
  }

  // ─── QR Code processing ────────────────────────────────────────────────

  Future<bool> processQrCode(String url, {bool isAvulsa = false, bool isPublic = false, Function(String)? onStatus}) async {
    _errorMessage = '';
    // NOTA: Intencionalmente NÃO chamamos notifyListeners() aqui.
    // A ScannerScreen gerencia seu próprio estado de loading (isProcessing).
    // Chamar notifyListeners() aqui conflita com o setState() do onStatus callback
    // e pode causar congelamento da UI.

    try {
      onStatus?.call('[1/5] Abrindo banco de dados...');
      bool exists = await _dbHelper.purchaseExists(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: banco de dados não respondeu em 10s. Reinicie o app.'),
      );
      if (exists) {
        _errorMessage = 'Nota Fiscal já foi lida.';
        notifyListeners();
        return false;
      }

      onStatus?.call('[2/5] Conectando ao Sefaz...');
      final result = await _scrapingService
          .fetchNotaFiscal(url, isAvulsa: isAvulsa, onStatus: onStatus)
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw Exception(
              'Tempo limite global (35s) atingido. Verifique sua conexão e tente novamente.',
            ),
          );

      if (result == null || (result['products'] as List).isEmpty) {
        _errorMessage =
            'Falha ao extrair itens da Nota Fiscal ou layout desconhecido.';
        notifyListeners();
        return false;
      }

      final oldPurchase = result['purchase'] as Purchase;
      final purchaseToSave = Purchase(
        date: oldPurchase.date,
        totalValue: oldPurchase.totalValue,
        url: oldPurchase.url,
        isAvulsa: isAvulsa,
        isPublic: isPublic,
      );

      onStatus?.call('[3/5] Salvando produtos no banco de dados...');
      await _dbHelper.insertPurchaseTransaction(
          purchaseToSave, result['products']
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout: falha ao salvar no banco de dados.'),
      );

      onStatus?.call('[4/5] Recarregando lista de produtos...');
      // Recarrega os produtos locais SEM chamar syncDownIfEmpty
      // para evitar requests extras que travem o fluxo de processamento.
      await loadProducts(skipSync: true);

      onStatus?.call('[5/5] Agendando backup na nuvem...');
      syncWithCloud(); // fire-and-forget intencional
      return true;
    } catch (e) {
      String errorStr = e.toString();
      if (errorStr.startsWith('Exception: ')) {
        errorStr = errorStr.substring(11);
      }
      _errorMessage = errorStr;
      notifyListeners();
      return false;
    }
  }

  // ─── Cloud sync (upload) ───────────────────────────────────────────────

  Future<void> syncWithCloud() async {
    _syncMessage = '🔄 Sincronizando com a nuvem...';
    notifyListeners();

    try {
      final unsyncedProducts = await _dbHelper.getUnsyncedProducts();
      if (unsyncedProducts.isEmpty) {
        _syncMessage = '✅ Tudo sincronizado.';
        notifyListeners();
        return;
      }

      final now = DateTime.now();
      final calculatedMonthlyTotal =
          await _dbHelper.getMonthlyTotal(now.month, now.year);

      final List<Map<String, dynamic>> productsToSync =
          unsyncedProducts.map((p) {
        final mutableMap = Map<String, dynamic>.from(p);
        mutableMap['monthvalue'] = calculatedMonthlyTotal;
        return mutableMap;
      }).toList();

      bool success = await _pocketBaseService.syncUnsyncedProducts(
        userId,
        productsToSync,
        householdId: currentHouseholdId,
        onMessage: (msg) {
          _syncMessage = msg;
          notifyListeners();
        },
      );

      if (success) {
        final Set<int> pIds = unsyncedProducts
            .map<int>((p) => p['purchase_id'] as int)
            .toSet();
        await _dbHelper.markPurchasesAsSynced(pIds.toList());
        _syncMessage = '✅ Sincronização concluída com sucesso!';
      } else {
        _syncMessage = '⚠️ Falha em alguns itens. Verifique os erros.';
      }
    } catch (e) {
      _syncMessage = '❌ Erro na nuvem: $e';
    }

    notifyListeners();
  }

  // ─── Other actions ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProductHistory(String name) async {
    return _dbHelper.getProductPriceHistory(name);
  }

  Future<void> uploadProductImage(String productName, File imageFile) async {
    await _pocketBaseService.uploadProductImageByName(
        productName, userId, imageFile);
  }

  Future<void> clearAllData() async {
    await _dbHelper.deleteAllData();
    _latestProducts = [];
    _errorMessage = '';
    _syncMessage = '';
    notifyListeners();
  }

  Future<void> forceSyncDown() async {
    _isLoading = true;
    notifyListeners();
    await _syncDownIfEmpty();
    await loadProducts(skipSync: true);
  }

  Future<bool> joinHousehold(String newHouseholdId) async {
    try {
      final model = _pocketBaseService.pb.authStore.model;
      if (model != null && model is RecordModel) {
        await _pocketBaseService.pb.collection('compras_users').update(model.id, body: {
          'household_id': newHouseholdId,
        });
        await _pocketBaseService.pb.collection('compras_users').authRefresh();
        notifyListeners();
        forceSyncDown(); // refresh from cloud
        return true;
      }
    } catch (e) {
      print('Erro ao juntar família: \$e');
    }
    return false;
  }

  Future<List<RecordModel>> getFamilyMembers() async {
    final hId = currentHouseholdId;
    if (hId.isEmpty) return [];
    try {
      // Usaremos try-catch e pb nativo
      final records = await _pocketBaseService.pb.collection('compras_users').getFullList(
        filter: 'id="$hId" || household_id="$hId"',
      );
      return records;
    } catch (e) {
      print('Erro ao buscar membros: $e');
      return [];
    }
  }

  Future<bool> removeFamilyMember(String memberId) async {
    try {
      await _pocketBaseService.pb.collection('compras_users').update(memberId, body: {
        'household_id': '',
      });
      // Force sync se for nós mesmos (fallback) ou simplesmente atualiza lista
      return true;
    } catch (e) {
      print('Erro ao remover membro: \$e');
      return false;
    }
  }
}
