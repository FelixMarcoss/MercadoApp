# MercadoApp — compras e gastos da casa

Aplicativo Flutter para registrar compras a partir do QR code de notas fiscais, acompanhar gastos mensais e compartilhar dados de produtos com pessoas da mesma família. Ele combina armazenamento local com sincronização em um serviço PocketBase.

> **Estado do projeto:** aplicativo em desenvolvimento. O fluxo completo depende de um servidor PocketBase compatível e da disponibilidade das páginas de nota fiscal consultadas. O esquema e a implantação desse servidor não estão neste repositório.

## Funcionalidades implementadas

- cadastro, login e restauração de sessão com PocketBase;
- leitura de QR code e extração de itens de uma página de nota fiscal;
- bloqueio de notas já importadas pela mesma URL;
- gravação de compras e produtos em SQLite;
- painel com total do mês, limite de gastos e compras recentes;
- lista de compras em andamento, com edição de quantidade e preço;
- histórico de preços por produto e visualização em gráfico;
- sincronização de produtos com a nuvem e compartilhamento por código de família;
- consulta a releases do GitHub para avisar sobre uma versão Android mais recente.

## Como os dados percorrem o aplicativo

```text
QR code da nota → leitura da página → extração dos produtos
                → transação SQLite → painel e histórico
                → sincronização PocketBase
```

O fluxo é coordenado por [`AppState`](lib/providers/app_state.dart). A extração de dados da nota fica em [`ScrapingService`](lib/services/scraping_service.dart), a persistência local em [`DatabaseHelper`](lib/database/database_helper.dart) e a sincronização em [`PocketBaseService`](lib/services/pocketbase_service.dart).

## Tecnologias

Flutter/Dart, Provider, SQLite (`sqflite`), PocketBase, `mobile_scanner`, `http`/`html` e `fl_chart`. As versões das dependências estão em [`pubspec.yaml`](pubspec.yaml).

## Executar

1. Instale o Flutter e configure um dispositivo Android ou emulador (`flutter doctor`).
2. Configure um servidor PocketBase com as coleções esperadas pelo aplicativo. O endereço do serviço está definido em [`lib/providers/auth_state.dart`](lib/providers/auth_state.dart); ajuste-o para o seu ambiente.
3. Na raiz do projeto, execute:

```bash
flutter pub get
flutter run
```

Sem uma conta válida no serviço PocketBase, o aplicativo abre a tela de login, mas os fluxos autenticados não podem ser testados. A leitura de notas também requer acesso à internet e um formato de página reconhecido pelo parser.

## Decisões e limites

- SQLite mantém o histórico local, enquanto a sincronização envia itens pendentes ao PocketBase.
- A extração depende do HTML da página de nota fiscal; mudanças nesse layout podem exigir atualização do parser.
- O endereço do backend e o esquema das coleções ainda precisam ser externalizados/documentados para uma instalação independente.
- O projeto inclui arquivos de outras plataformas gerados pelo Flutter, mas o fluxo com câmera e atualização por APK foi desenvolvido para Android.
