import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

/// Service for all PocketBase data operations.
/// Uses [userId] to scope all reads/writes to the authenticated user.
class PocketBaseService {
  final PocketBase pb;
  static const String collectionName = 'lista_compras';

  PocketBaseService(this.pb);

  /// Fetches all records belonging to [userId] from the cloud.
  /// Used to seed a fresh local SQLite database.
  Future<List<Map<String, dynamic>>> fetchAllProducts(String userId, {String householdId = ''}) async {
    try {
      // Sem filtro! Vamos puxar todas as notas públicas (toda a collection)
      final records = await pb.collection(collectionName).getFullList();
      return records.map((r) => r.toJson()).toList();
    } catch (e) {
      print('⚠️ Erro ao buscar produtos da nuvem: $e');
      return [];
    }
  }

  /// Uploads all unsynced [products] to PocketBase tagged with [userId].
  /// The [onMessage] callback streams log messages to the UI in real-time.
  Future<bool> syncUnsyncedProducts(
    String userId,
    List<Map<String, dynamic>> products, {
    String householdId = '',
    Function(String)? onMessage,
  }) async {
    void log(String msg) {
      onMessage?.call(msg);
      print(msg);
    }

    if (products.isEmpty) return true;

    bool allSuccess = true;

    for (var product in products) {
      final name = product['name']?.toString() ?? 'Desconhecido';
      final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (product['quantity'] as num?)?.toDouble() ?? 1.0;
      final unitType = product['unit_type']?.toString() ?? 'un';
      final isAvulsa = product['avulsa'] == 1;
      final isPublic = product['is_public'] == 1;
      final monthvalue = (product['monthvalue'] as num?)?.toDouble() ?? 0.0;
      final purchaseDate = product['purchase_date']?.toString() ??
          DateTime.now().toUtc().toIso8601String();

      try {
        await pb.collection(collectionName).create(
          body: {
            'user_id': userId,  // ← isolamento por usuário
            'household_id': isPublic ? householdId : '',
            'produto': name,
            'quantidade': quantity,
            'unidade': unitType,
            'categoria': 'N/A',
            'comprado': true,
            'preco_medio': price,
            'frequencia_dias': 0,
            'ultima_compra': purchaseDate,
            'avulsa': isAvulsa,
            'monthvalue': monthvalue,
          },
        );
        log('✅ Histórico Salvo na Nuvem: $name (Data: $purchaseDate)');

        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        allSuccess = false;
        log('❌ Falha Crítica "$name": $e');
      }
    }

    return allSuccess;
  }

  /// Uploads a product photo to an existing PocketBase record.
  Future<bool> uploadProductImageByName(
      String productName, String userId, File imageFile) async {
    try {
      final safeName = productName.replaceAll('"', '\\"');
      final filterStr = 'produto="$safeName" && user_id="$userId"';

      final record =
          await pb.collection(collectionName).getFirstListItem(filterStr);

      final multipartFile =
          await http.MultipartFile.fromPath('fotos', imageFile.path);

      await pb.collection(collectionName).update(
        record.id,
        files: [multipartFile],
      );

      return true;
    } catch (e) {
      if (e is ClientException && e.statusCode == 404) {
        print(
            '⚠️ Foto não enviada: Produto "$productName" não existe na nuvem.');
      } else {
        print('⚠️ Erro ao enviar foto para "$productName": $e');
      }
      return false;
    }
  }
}
