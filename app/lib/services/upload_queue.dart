import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'settings.dart';

/// Fila de envio offline: guarda arquivo + metadados localmente e reenvia quando houver internet.
class UploadItem {
  UploadItem(this.meta, this.path);
  final Map<String, dynamic> meta; // device_uuid, tipo, placa_cavalo, ...
  final String path;

  Map<String, dynamic> toJson() => {'meta': meta, 'path': path};
  factory UploadItem.fromJson(Map<String, dynamic> j) =>
      UploadItem(Map<String, dynamic>.from(j['meta']), j['path'] as String);
}

class UploadQueue {
  UploadQueue(this.settings);
  final Settings settings;
  static const _k = 'fila';
  bool _enviando = false;

  List<UploadItem> pendentes() {
    final raw = settings.raw.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => UploadItem.fromJson(e)).toList();
  }

  Future<void> _salvar(List<UploadItem> l) =>
      settings.raw.setString(_k, jsonEncode(l.map((e) => e.toJson()).toList()));

  Future<void> adicionar(UploadItem i) async => _salvar([...pendentes(), i]);

  /// Tenta enviar tudo. Retorna quantos foram enviados.
  Future<int> enviarTudo() async {
    if (_enviando) return 0;
    _enviando = true;
    var ok = 0;
    try {
      var lista = pendentes();
      for (final item in List.of(lista)) {
        if (!await File(item.path).exists()) {
          lista.remove(item);
          await _salvar(lista);
          continue;
        }
        if (await _enviar(item)) {
          ok++;
          lista.remove(item);
          await _salvar(lista);
          try { await File(item.path).delete(); } catch (_) {}
        } else {
          break; // sem rede/servidor: tenta de novo depois
        }
      }
    } finally {
      _enviando = false;
    }
    return ok;
  }

  Future<bool> _enviar(UploadItem i) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${settings.apiUrl}/api/registros'))
        ..headers['Accept'] = 'application/json';
      if (settings.apiKey.isNotEmpty) req.headers['X-Api-Key'] = settings.apiKey;
      i.meta.forEach((k, v) {
        if (v != null && '$v'.isNotEmpty) req.fields[k] = '$v';
      });
      req.files.add(await http.MultipartFile.fromPath('arquivo', i.path));
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 2)));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      // 422 = dados inválidos: não adianta reenviar para sempre; descarta para não travar a fila.
      return res.statusCode == 422;
    } catch (_) {
      return false;
    }
  }
}
