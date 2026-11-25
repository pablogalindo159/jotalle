import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'settings.dart';

enum EnvioStatus { enviado, pendente, rejeitado }

class UploadItem {
  UploadItem(this.meta, this.path);
  final Map<String, dynamic> meta; // device_uuid, tipo, motorista, placa_cavalo, ...
  final String path;

  String get id => meta['device_uuid'] as String;

  Map<String, dynamic> toJson() => {'meta': meta, 'path': path};
  factory UploadItem.fromJson(Map<String, dynamic> j) =>
      UploadItem(Map<String, dynamic>.from(j['meta']), j['path'] as String);
}

/// Fila de envio offline: guarda arquivo + metadados localmente e reenvia quando houver internet.
class UploadQueue {
  UploadQueue(this.settings);
  final Settings settings;
  static const _k = 'fila';
  bool _enviando = false;

  /// Itens que o servidor recusou (HTTP 422): id -> motivo. O arquivo local é mantido.
  final Map<String, String> rejeitados = {};
  final Set<String> _enviados = {};

  List<UploadItem> pendentes() {
    final raw = settings.raw.getString(_k);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => UploadItem.fromJson(e)).toList();
  }

  Future<void> _salvar(List<UploadItem> l) =>
      settings.raw.setString(_k, jsonEncode(l.map((e) => e.toJson()).toList()));

  Future<void> adicionar(UploadItem i) async => _salvar([...pendentes(), i]);

  /// Resultado do envio de um item: enviado ao servidor, pendente (sem rede/servidor) ou recusado.
  EnvioStatus status(String id) {
    if (rejeitados.containsKey(id)) return EnvioStatus.rejeitado;
    if (pendentes().any((i) => i.id == id)) return EnvioStatus.pendente;
    return _enviados.contains(id) ? EnvioStatus.enviado : EnvioStatus.pendente;
  }

  /// Tenta enviar tudo. Retorna quantos foram enviados.
  Future<int> enviarTudo() async {
    // se já há um envio em andamento, espera ele terminar
    while (_enviando) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _enviando = true;
    var ok = 0;
    try {
      final lista = pendentes();
      for (final item in List.of(lista)) {
        if (!await File(item.path).exists()) {
          lista.remove(item);
          await _salvar(lista);
          continue;
        }
        final r = await _enviar(item);
        if (r.estado == 1) {
          ok++;
          _enviados.add(item.id);
          lista.remove(item);
          await _salvar(lista);
          try { await File(item.path).delete(); } catch (_) {}
        } else if (r.estado == -1) {
          rejeitados[item.id] = r.msg; // não trava a fila; arquivo fica para o usuário salvar
          lista.remove(item);
          await _salvar(lista);
        } else {
          break; // sem rede/servidor: tenta de novo depois
        }
      }
    } finally {
      _enviando = false;
    }
    return ok;
  }

  /// estado: 1 = salvo no servidor, 0 = tentar depois, -1 = servidor recusou os dados.
  Future<({int estado, String msg})> _enviar(UploadItem i) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse('${settings.apiUrl}/api/registros'))
        ..headers['Accept'] = 'application/json';
      if (settings.apiKey.isNotEmpty) req.headers['X-Api-Key'] = settings.apiKey;
      i.meta.forEach((k, v) {
        if (v != null && '$v'.isNotEmpty) req.fields[k] = '$v';
      });
      req.files.add(await http.MultipartFile.fromPath('arquivo', i.path));
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 2)));
      if (res.statusCode == 200 || res.statusCode == 201) return (estado: 1, msg: '');
      if (res.statusCode == 422) {
        String m = 'dados inválidos';
        try { m = (jsonDecode(res.body)['message'] ?? m).toString(); } catch (_) {}
        return (estado: -1, msg: m);
      }
      return (estado: 0, msg: 'HTTP ${res.statusCode}');
    } catch (_) {
      return (estado: 0, msg: 'sem conexão');
    }
  }
}
