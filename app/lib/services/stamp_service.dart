import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'location_service.dart';

const _dias = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];

String two(int n) => n.toString().padLeft(2, '0');

String diaDataHora(DateTime d) =>
    '${_dias[d.weekday - 1]}, ${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

/// -23.5475 -> 23°32'51.0"S
String dms(double v, String pos, String neg) {
  final hemi = v < 0 ? neg : pos;
  final a = v.abs();
  final g = a.floor();
  final mFull = (a - g) * 60;
  final m = mFull.floor();
  final s = (mFull - m) * 60;
  return '$g°${two(m)}\'${s.toStringAsFixed(1).padLeft(4, '0')}"$hemi';
}

String coordenadas(double lat, double lng) => '${dms(lat, 'N', 'S')}  ${dms(lng, 'E', 'W')}';

class StampData {
  StampData({required this.motorista, required this.placa, required this.carreta, required this.quando, this.local});
  final String motorista, placa, carreta;
  final DateTime quando;
  final LocalFix? local;
}

class StampService {
  /// Desenha PLACA/CARRETA, data/hora, endereço e coordenadas na foto, com PIPs no topo
  /// (esquerda: print do mapa, direita: foto extra opcional). Devolve JPEG.
  Future<Uint8List> gerar({
    required File principal,
    required StampData dados,
    Uint8List? mapaPng,
    File? extra,
  }) async {
    final base = await _decode(await principal.readAsBytes());
    final w = base.width.toDouble(), h = base.height.toDouble();
    final s = w / 1080;

    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w, h));
    c.drawImage(base, ui.Offset.zero, ui.Paint());

    // PIPs (topo)
    final pip = w * 0.30;
    final margem = 24 * s;
    if (mapaPng != null) {
      await _pip(c, await _decode(mapaPng), ui.Rect.fromLTWH(margem, margem, pip, pip), s);
    }
    if (extra != null) {
      await _pip(c, await _decode(await extra.readAsBytes()), ui.Rect.fromLTWH(w - margem - pip, margem, pip, pip), s);
    }

    // Faixa de texto (rodapé)
    final l = dados.local;
    final linhas = <TextPainter>[
      _tp('MOTORISTA: ${dados.motorista}', 50 * s, bold: true, maxW: w - 2 * margem),
      _tp('PLACA CAVALO: ${dados.placa}', 50 * s, bold: true, maxW: w - 2 * margem),
      _tp('PLACA CARRETA: ${dados.carreta.isEmpty ? '-' : dados.carreta}', 50 * s, bold: true, maxW: w - 2 * margem),
      _tp(diaDataHora(dados.quando), 36 * s, maxW: w - 2 * margem),
      _tp(l == null || l.endereco.vazio ? 'Endereço indisponível' : l.endereco.linha, 34 * s, maxW: w - 2 * margem),
      _tp(l == null ? 'Coordenadas indisponíveis' : coordenadas(l.lat, l.lng), 34 * s, maxW: w - 2 * margem),
    ];
    final altTexto = linhas.fold<double>(0, (a, t) => a + t.height) + 6 * s * (linhas.length - 1);
    final faixa = altTexto + 2 * margem * 0.8;
    c.drawRect(ui.Rect.fromLTWH(0, h - faixa, w, faixa), ui.Paint()..color = const ui.Color(0xB3000000));
    var y = h - faixa + margem * 0.8;
    for (final t in linhas) {
      t.paint(c, ui.Offset(margem, y));
      y += t.height + 6 * s;
    }

    final out = await rec.endRecording().toImage(base.width, base.height);
    final bd = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
    return compute(_encodeJpg, _Raw(base.width, base.height, bd!.buffer.asUint8List()));
  }

  Future<void> _pip(ui.Canvas c, ui.Image im, ui.Rect dst, double s) async {
    // recorte quadrado centralizado (cover)
    final lado = im.width < im.height ? im.width.toDouble() : im.height.toDouble();
    final src = ui.Rect.fromLTWH((im.width - lado) / 2, (im.height - lado) / 2, lado, lado);
    c.drawRect(dst.inflate(5 * s), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    c.drawImageRect(im, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.high);
  }

  TextPainter _tp(String t, double size, {bool bold = false, required double maxW}) => TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: size,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            height: 1.15,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: maxW);

  Future<ui.Image> _decode(Uint8List b) async => (await (await ui.instantiateImageCodec(b)).getNextFrame()).image;
}

class _Raw {
  _Raw(this.w, this.h, this.rgba);
  final int w, h;
  final Uint8List rgba;
}

Uint8List _encodeJpg(_Raw r) {
  final im = img.Image.fromBytes(width: r.w, height: r.h, bytes: r.rgba.buffer, numChannels: 4);
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}
