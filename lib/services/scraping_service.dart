import 'dart:async';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:http/io_client.dart';

import '../models/product.dart';
import '../models/purchase.dart';

class ScrapingService {
  Future<Map<String, dynamic>?> fetchNotaFiscal(
    String url, {
    bool isAvulsa = false,
    Function(String)? onStatus,
  }) async {
    // Cria um HttpClient com timeout de conexão e recebimento explícitos.
    // Isso garante que sockets travados (que nunca retornam dados)
    // também são abortados, ao contrário do .timeout() simples do Dart.
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20);
    final ioClient = IOClient(httpClient);

    try {
      onStatus?.call('Conectando ao Sefaz...');
      final response = await ioClient
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'pt-BR,pt;q=0.9',
            },
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException(
              'Timeout de 25s atingido. O servidor do Sefaz está lento ou bloqueou a requisição.',
            ),
          );

      if (response.statusCode != 200) {
        throw Exception('Servidor indisponível (Erro HTTP ${response.statusCode}).');
      }

      onStatus?.call('HTML recebido. Analisando conteúdo...');
      final document = html_parser.parse(response.body);

      // -------------------------------------------------------
      // 1. EXTRACT PRODUCTS from tbody#myTable
      // -------------------------------------------------------
      // Structure per <tr>:
      //   td[0]: <h7>PRODUCT NAME</h7>(Código: XXXXX)
      //   td[1]: "Qtde total de ítens: 1.0000"
      //   td[2]: "UN: PC"
      //   td[3]: "Valor total R$: R$ 6,48"
      // -------------------------------------------------------
      final myTable = document.getElementById('myTable');
      if (myTable == null) {
        throw Exception('Lista de produtos não encontrada. O site da Sefaz pode estar fora do ar, requerer Captcha ou o link falhou.');
      }

      final rows = myTable.getElementsByTagName('tr');
      final List<Product> products = [];

      for (var tr in rows) {
        final tds = tr.getElementsByTagName('td');
        if (tds.length < 4) continue;

        // Product name: text inside <h7> tag in td[0]
        final h7 = tds[0].getElementsByTagName('h7');
        if (h7.isEmpty) continue;
        final name = h7.first.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (name.isEmpty) continue;

        // Quantity: "Qtde total de ítens: 1.0000"
        final qtdText = tds[1].text.trim();
        final quantity = _extractAfterLabel(qtdText, 'Qtde total de ítens:');

        // Unit type: "UN: PC"
        final unText = tds[2].text.trim();
        final unitType = _extractStringAfterLabel(unText, 'UN:');

        // Total price: "Valor total R$: R$ 6,48"
        // Usamos Regex direto para achar qualquer número com formato BR na string
        final valText = tds[3].text.trim();
        final totalPrice = _extractLastNumber(valText);

        // Unit price
        final unitPrice = quantity > 0 ? totalPrice / quantity : totalPrice;

        products.add(
          Product(
            purchaseId: 0, // assigned by DB later
            name: name,
            quantity: quantity == 0 ? 1.0 : quantity,
            unitType: unitType.isEmpty ? 'UN' : unitType,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            isAvulsa: isAvulsa,
          ),
        );
      }

      if (products.isEmpty) {
        throw Exception('A nota foi acessada, mas não achamos nenhum item nela.');
      }
      onStatus?.call('Finalizando extração da Nota Fiscal...');

      // -------------------------------------------------------
      // 2. EXTRACT DATE
      // Looks for a text containing "Data de Emissão" or "Emissão"
      // and parses the Brazilian datetime format DD/MM/YYYY HH:MM:SS
      // -------------------------------------------------------
      String purchaseDate = DateTime.now().toIso8601String();

      // Try to find date in the whole page text
      final bodyText = document.body?.text ?? '';
      final dateRegex = RegExp(
        r'(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
      );
      final dateMatch = dateRegex.firstMatch(bodyText);
      if (dateMatch != null) {
        final day = dateMatch.group(1)!.padLeft(2, '0');
        final month = dateMatch.group(2)!.padLeft(2, '0');
        final year = dateMatch.group(3)!;
        final hour = dateMatch.group(4)!.padLeft(2, '0');
        final min = dateMatch.group(5)!.padLeft(2, '0');
        final sec = dateMatch.group(6)!.padLeft(2, '0');
        purchaseDate = '$year-$month-${day}T$hour:$min:$sec';
      } else {
        // Fallback: find any date DD/MM/YYYY in the page
        final dateOnlyRegex = RegExp(r'(\d{2})/(\d{2})/(\d{4})');
        final dateOnlyMatch = dateOnlyRegex.firstMatch(bodyText);
        if (dateOnlyMatch != null) {
          final day = dateOnlyMatch.group(1)!;
          final month = dateOnlyMatch.group(2)!;
          final year = dateOnlyMatch.group(3)!;
          purchaseDate = '$year-$month-${day}T00:00:00';
        }
      }

      // -------------------------------------------------------
      // 3. EXTRACT TOTAL VALUE
      // Sum from products as ground truth (more reliable than scraping total)
      // -------------------------------------------------------
      final totalValue = products.fold(0.0, (sum, p) => sum + p.totalPrice);

      final purchase = Purchase(
        date: purchaseDate,
        totalValue: totalValue,
        url: url,
        isAvulsa: isAvulsa,
      );

      return {'purchase': purchase, 'products': products};
    } on TimeoutException catch (e) {
      throw Exception(
        e.message ?? 'Tempo limite excedido conectando ao Sefaz. O servidor está lento ou bloqueou a requisição.',
      );
    } on SocketException catch (e) {
      throw Exception('Erro de rede: Sem conexão ou host inacessível. (${e.message})');
    } catch (e, stack) {
      print('ScrapingService error: $e');
      print(stack);
      rethrow;
    } finally {
      ioClient.close();
    }
  }

  // Extrai o ÚLTIMO número no formato BR (ex: "6,48" ou "1.200,50") encontrado na string.
  // Isso evita problemas de busca por label, já que o R$ pode ter variações de espaço.
  // Exemplo: "Valor total R$: R$ 6,48" → 6.48
  double _extractLastNumber(String text) {
    // Regex para número no formato pt_BR: pode ter separadores de milhar (.) e virgula decimal
    final numRegex = RegExp(r'\d{1,3}(?:\.\d{3})*,\d+|\d+,\d+|\d+\.\d+|\d+');
    final matches = numRegex.allMatches(text);
    if (matches.isEmpty) return 0.0;
    // Pega o último (que costuma ser o valor final na string "R$ 6,48")
    final lastMatch = matches.last.group(0)!;
    return _parseBrNumber(lastMatch);
  }

  // Extrai o número após um label textual (ex: "Qtde total de ítens: 1.0000" → 1.0)
  double _extractAfterLabel(String text, String label) {
    final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ');
    final idx = normalizedText.indexOf(label);
    if (idx == -1) return 0.0;
    final sub = normalizedText.substring(idx + label.length).trim();
    final numRegex = RegExp(r'\d{1,3}(?:\.\d{3})*,\d+|\d+,\d+|\d+\.\d+|\d+');
    final match = numRegex.firstMatch(sub);
    if (match == null) return 0.0;
    return _parseBrNumber(match.group(0)!);
  }

  // Extracts a trimmed word after the label.
  // Example: "UN: PC" → "PC"
  String _extractStringAfterLabel(String text, String label) {
    final idx = text.indexOf(label);
    if (idx == -1) return '';
    final sub = text.substring(idx + label.length).trim();
    return sub.split(RegExp(r'\s+')).first;
  }

  // Parses Brazilian numeric format: "1.234,56" → 1234.56
  // Parses mixed numeric formats from SEFAZ
  double _parseBrNumber(String val) {
    String cleaned = val.trim();

    // Se tem ponto E vírgula (ex: "1.234,56") -> Padrão BR com milhar
    if (cleaned.contains('.') && cleaned.contains(',')) {
      cleaned = cleaned.replaceAll('.', '');
      cleaned = cleaned.replaceAll(',', '.');
    }
    // Se tem APENAS vírgula (ex: "6,48") -> Padrão BR simples
    else if (cleaned.contains(',')) {
      cleaned = cleaned.replaceAll(',', '.');
    }
    // Se tem apenas ponto (ex: "1.0000" ou "855.98") -> Padrão Americano
    // O double.tryParse do Dart já entende esse formato naturalmente,
    // então não precisamos fazer nenhum replace.

    return double.tryParse(cleaned) ?? 0.0;
  }
}
