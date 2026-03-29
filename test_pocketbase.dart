import 'package:pocketbase/pocketbase.dart';

const String projectId = 'LISTA_WIN_TEST_001';
const String collectionName = 'lista_compras';

void main() async {
  print('🟢 INICIANDO TESTE DO POCKETBASE SDK 🟢\n');

  final pb = PocketBase('https://telemetria.minacon.com.br');

  print('--- Testando ESCRITA (CREATE) ---');
  try {
    final newItem = {
      "project_id": projectId,
      "produto":
          "Item de Teste Dart SDK \${DateTime.now().millisecondsSinceEpoch}",
      "quantidade": 1,
      "unidade": "un",
      "categoria": "Limpeza",
      "comprado": false,
      "preco_medio": 10.99,
      "frequencia_dias": 0,
      "ultima_compra": DateTime.now().toUtc().toIso8601String(),
    };

    print('Enviando payload: $newItem');

    final record = await pb.collection(collectionName).create(body: newItem);
    print('✅ SUCESSO! Item criado com ID: ${record.id}');

    print('\n--- Testando LEITURA (READ) ---');
    print('Consultando lista para PROJECT_ID: $projectId...');

    final resultList = await pb
        .collection(collectionName)
        .getList(page: 1, perPage: 50);

    print(
      '✅ SUCESSO! ${resultList.totalItems} itens encontrados no banco (Página 1 tem ${resultList.items.length}).',
    );
    if (resultList.items.isNotEmpty) {
      print(
        'Primeiro item na lista: ${resultList.items.first.data['produto']}',
      );
    }
  } catch (e) {
    print('❌ Erro de conexão/API: $e');
  }

  print('\n🔴 TESTE FINALIZADO 🔴');
}
