import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://telemetria.minacon.com.br');
  const collectionName = 'lista_compras';
  const projectId = 'AppMercado';

  final records = await pb.collection(collectionName).getFullList(
        filter: 'project_id="$projectId"',
      );

  print('Total records in PB: \${records.length}');
  
  // See Leite Integral
  final leite = records.where((r) => r.data['produto'] == 'Leite Integral 1L');
  print('Leite Integral records count: \${leite.length}');
  for (var r in leite) {
    print('Leite: \${r.data['preco_medio']} na data \${r.data['ultima_compra']}');
  }
}
