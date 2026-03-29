import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://telemetria.minacon.com.br');
  const String projectId = 'AppMercado';
  const String collectionName = 'lista_compras';

  print('Preparando injeção de Mock Data no Servidor PocketBase...');

  try {
    // Definir os meses passados que vamos simular
    final now = DateTime.now().toUtc();
    final mes3 = now.subtract(const Duration(days: 90)).toIso8601String();
    final mes2 = now.subtract(const Duration(days: 60)).toIso8601String();
    final mes1 = now.subtract(const Duration(days: 30)).toIso8601String();
    final hoje = now.toIso8601String();

    // =============== PRODUTO 1: Leite Integral ===============
    print('Criando Histórico: Leite Integral 1L...');
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Leite Integral 1L',
            'quantidade': 12.0,
            'unidade': 'cx',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 4.50,
            'ultima_compra': mes3,
            'avulsa': false,
            'monthvalue': 400.0, // Fictício
          },
        );
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Leite Integral 1L',
            'quantidade': 12.0,
            'unidade': 'cx',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 5.20,
            'ultima_compra': mes2,
            'avulsa': false,
            'monthvalue': 400.0, // Fictício
          },
        );
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Leite Integral 1L',
            'quantidade': 12.0,
            'unidade': 'cx',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 5.80,
            'ultima_compra': mes1,
            'avulsa': false,
            'monthvalue': 400.0, // Fictício
          },
        );
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Leite Integral 1L',
            'quantidade': 12.0,
            'unidade': 'cx',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 6.10,
            'ultima_compra': hoje,
            'avulsa': false,
            'monthvalue': 400.0, // Fictício
          },
        );

    // =============== PRODUTO 2: Óleo de Soja ===============
    print('Criando Histórico: Óleo de Soja 900ml...');
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Óleo de Soja 900ml',
            'quantidade': 2.0,
            'unidade': 'l',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 6.50,
            'ultima_compra': mes2,
            'avulsa': true,
            'monthvalue': 100.0,
          },
        );
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Óleo de Soja 900ml',
            'quantidade': 4.0,
            'unidade': 'l',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 7.90,
            'ultima_compra': mes1,
            'avulsa': false,
            'monthvalue': 300.0,
          },
        );
    await pb
        .collection(collectionName)
        .create(
          body: {
            'project_id': projectId,
            'produto': 'Óleo de Soja 900ml',
            'quantidade': 3.0,
            'unidade': 'l',
            'categoria': 'Mocks',
            'comprado': true,
            'preco_medio': 8.50,
            'ultima_compra': hoje,
            'avulsa': false,
            'monthvalue': 350.0,
          },
        );

    print('✅ Mocks inseridos na nuvem!');

    // Verificação Crítica: PocketBase salvou o campo 'ultima_compra'?
    print(
      '🔍 Lendo de volta um registro para verificar a estrutura do banco...',
    );
    final checkRecords = await pb
        .collection(collectionName)
        .getList(
          page: 1,
          perPage: 1,
          filter: 'project_id="\$projectId"',
          sort: '-created',
        );

    if (checkRecords.items.isNotEmpty) {
      final record = checkRecords.items.first;
      final savedData = record.toJson();
      if (!savedData.containsKey('ultima_compra') &&
          !record.data.containsKey('ultima_compra')) {
        print(
          '\\n❌ ATENÇÃO MÁXIMA: O campo "ultima_compra" NÃO foi salvo pelo PocketBase!',
        );
        print(
          'Isso significa que a coluna "ultima_compra" não existe (ou está com nome errado) no painel do PocketBase.',
        );
        print(
          'Como o PocketBase ignorou nossa data antiga, o app puxou esses dados com a data de "created" (HOJE).',
        );
        print(
          'Como todos os mocks ficaram com a data de hoje, o gráfico fundiu todos em APENAS 1 COMPRA REGISTRADA!',
        );
        print('\\nO QUE VOCÊ DEVE FAZER:');
        print('1. Abra seu painel do PocketBase (Admin UI).');
        print('2. Vá na coleção "lista_compras".');
        print('3. Clique na engrenagem de configurações/campos.');
        print(
          '4. Adicione um novo campo (pode ser tipo "Empty" / Text ou Date).',
        );
        print(
          '5. Nomeie o campo exatamente como: ultima_compra (em minúsculas).',
        );
        print('6. Salve a coleção, rode este script de novo e limpe o App!\\n');
      } else {
        print(
          '\\n✅ O campo "ultima_compra" existe no banco e foi lido com sucesso!',
        );
      }
    }

    print('✅ Mocks inseridos com sucesso NA NUVEM!');
    print(
      'Abra seu aplicativo, limpe os dados (se necessário para acionar o SyncDownIfEmpty) ou aguarde o upload, e verifique o gráfico de histórico para "Leite Integral 1L" ou "Óleo de Soja 900ml".',
    );
  } catch (e) {
    print('❌ Erro Crítico ao injetar dados na nuvem: \$e');
  }
}
