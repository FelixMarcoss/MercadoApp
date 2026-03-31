import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:version/version.dart';

class UpdateService {
  static const String repoUrl = 'https://api.github.com/repos/FelixMarcoss/MercadoApp/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(repoUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String tagName = data['tag_name'];
        final String releaseNotes = data['body'] ?? 'Nova versão disponível!';
        final List assets = data['assets'];

        if (assets.isEmpty) return; // No APK attached
        
        // Find APK asset
        final apkAsset = assets.firstWhere((asset) => asset['name'].toString().endsWith('.apk'), orElse: () => null);
        if (apkAsset == null) return;

        final downloadUrl = apkAsset['browser_download_url'];

        // Compare Versions
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        final currentVersionStr = packageInfo.version;

        // Clean up "v" prefix if any e.g. "v1.0.0" -> "1.0.0"
        final remoteVersionStr = tagName.replaceAll('v', '').trim();
        final currentVer = Version.parse(currentVersionStr);
        final remoteVer = Version.parse(remoteVersionStr);

        if (remoteVer > currentVer) {
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersionStr, releaseNotes, downloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Update check failed quietly: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String newVersion,
    String releaseNotes,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdatePromptModal(
        newVersion: newVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      ),
    );
  }
}

class _UpdatePromptModal extends StatefulWidget {
  final String newVersion;
  final String releaseNotes;
  final String downloadUrl;

  const _UpdatePromptModal({
    required this.newVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  @override
  State<_UpdatePromptModal> createState() => _UpdatePromptModalState();
}

class _UpdatePromptModalState extends State<_UpdatePromptModal> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Baixando...';
    });

    try {
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/mercado_update.apk';

      await dio.download(
        widget.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      setState(() {
        _statusMessage = 'Instalando...';
      });

      // Trigger Install
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        setState(() {
          _statusMessage = 'Erro ao abrir APK: ${result.message}';
          _isDownloading = false;
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Falha no download.';
      });
      debugPrint('Download falhou: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nova Versão ${widget.newVersion}!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novidades:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.releaseNotes,
              style: const TextStyle(fontSize: 14),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mais tarde'),
          ),
        if (!_isDownloading)
          ElevatedButton(
            onPressed: _downloadAndInstall,
            child: const Text('Atualizar Agora'),
          ),
      ],
    );
  }
}
