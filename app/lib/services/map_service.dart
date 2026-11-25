import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'settings.dart';

/// Gera o "print" do mapa (PNG 512x512) que vai no PIP. OSM principal; Google opcional (chave nas configurações).
class MapService {
  MapService(this.settings);
  final Settings settings;
  static const _size = 512;
  static const _zoom = 17;

  Future<Uint8List?> gerar(double lat, double lng) async {
    final ordem = settings.mapa == MapaProvedor.google ? [_google, _osm] : [_osm, _google];
    for (final f in ordem) {
      try {
        final b = await f(lat, lng).timeout(const Duration(seconds: 15));
        if (b != null) return b;
      } catch (_) {}
    }
    return null;
  }

  Future<Uint8List?> _google(double lat, double lng) async {
    final key = settings.googleKey;
    if (key.isEmpty) return null;
    final r = await http.get(Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
      'center': '$lat,$lng', 'zoom': '$_zoom', 'size': '${_size}x$_size',
      'markers': 'color:red|$lat,$lng', 'key': key,
    }));
    return r.statusCode == 200 && (r.headers['content-type'] ?? '').startsWith('image') ? r.bodyBytes : null;
  }

  /// Monta 3x3 tiles do OpenStreetMap em volta do ponto e desenha o marcador.
  Future<Uint8List?> _osm(double lat, double lng) async {
    final n = math.pow(2, _zoom).toDouble();
    final x = (lng + 180) / 360 * n;
    final latRad = lat * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;
    final tx = x.floor(), ty = y.floor();
    final fx = x - tx, fy = y - ty;

    final futures = <Future<ui.Image?>>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        futures.add(_tile(tx + dx, ty + dy));
      }
    }
    final tiles = await Future.wait(futures);
    if (tiles.every((t) => t == null)) return null;

    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, _size.toDouble(), _size.toDouble()));
    c.drawRect(ui.Rect.fromLTWH(0, 0, _size.toDouble(), _size.toDouble()), ui.Paint()..color = const ui.Color(0xFFE5E3DF));
    // O ponto fica no centro (256,256): deslocamento = 256 - (256 + fração*256).
    final ox = _size / 2 - (256 + fx * 256);
    final oy = _size / 2 - (256 + fy * 256);
    for (var i = 0; i < 9; i++) {
      final t = tiles[i];
      if (t != null) c.drawImage(t, ui.Offset(ox + (i % 3) * 256, oy + (i ~/ 3) * 256), ui.Paint());
    }
    // marcador
    final centro = ui.Offset(_size / 2, _size / 2);
    c.drawCircle(centro, 20, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    c.drawCircle(centro, 14, ui.Paint()..color = const ui.Color(0xFFE53935));
    c.drawCircle(centro, 5, ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    // atribuição obrigatória do OSM
    final tp = TextPainter(
      text: const TextSpan(text: '© OpenStreetMap', style: TextStyle(color: Color(0xFF222222), fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    c.drawRect(ui.Rect.fromLTWH(_size - tp.width - 12, _size - tp.height - 6, tp.width + 12, tp.height + 6),
        ui.Paint()..color = const ui.Color(0xCCFFFFFF));
    tp.paint(c, ui.Offset(_size - tp.width - 6, _size - tp.height - 3));

    final img = await rec.endRecording().toImage(_size, _size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<ui.Image?> _tile(int x, int y) async {
    try {
      final r = await http.get(Uri.parse('https://tile.openstreetmap.org/$_zoom/$x/$y.png'),
          headers: {'User-Agent': kUserAgent}).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(r.bodyBytes);
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }
}
