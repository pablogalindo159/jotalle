import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'settings.dart';

class Endereco {
  Endereco({this.rua = '', this.numero = '', this.bairro = '', this.cidade = '', this.estado = ''});
  final String rua, numero, bairro, cidade, estado;

  /// "Rua X, 123" (só o nome da rua se o número não for encontrado)
  String get ruaNum => numero.isNotEmpty && rua.isNotEmpty ? '$rua, $numero' : rua;
  String get linha => [ruaNum, bairro, cidade, estado].where((e) => e.isNotEmpty).join(', ');
  bool get vazio => linha.isEmpty;

  Endereco comNumero(String n) =>
      Endereco(rua: rua, numero: n, bairro: bairro, cidade: cidade, estado: estado);
}

class LocalFix {
  LocalFix(this.lat, this.lng, this.endereco);
  final double lat, lng;
  final Endereco endereco;
}

class LocationService {
  LocationService(this.settings);
  final Settings settings;

  /// Pega a posição atual (lança se sem permissão/GPS) e tenta o endereço (OSM principal, Google alternativo).
  Future<LocalFix> obter() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'GPS desligado. Ligue a localização do aparelho.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw 'Sem permissão de localização.';
    }
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima == null) throw 'Não consegui pegar o GPS. Vá para um local aberto.';
      pos = ultima;
    }
    final end = await _endereco(pos.latitude, pos.longitude);
    return LocalFix(pos.latitude, pos.longitude, end);
  }

  Future<Endereco> _endereco(double lat, double lng) async {
    final ordem = settings.mapa == MapaProvedor.google
        ? [_google, _osm]
        : [_osm, _google];
    Endereco? base;
    for (final f in ordem) {
      try {
        final e = await f(lat, lng).timeout(const Duration(seconds: 10));
        if (e == null || e.vazio) continue;
        if (base == null) {
          base = e;
        } else if (base.numero.isEmpty && e.numero.isNotEmpty) {
          base = base.comNumero(e.numero); // número da casa vindo do outro provedor
        }
        if (base.numero.isNotEmpty) break;
      } catch (_) {}
    }
    return base ?? Endereco();
  }

  Future<Endereco?> _osm(double lat, double lng) async {
    final r = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2', 'lat': '$lat', 'lon': '$lng', 'addressdetails': '1', 'zoom': '18', 'accept-language': 'pt-BR',
      }),
      headers: {'User-Agent': kUserAgent},
    ).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final a = (jsonDecode(r.body)['address'] ?? {}) as Map<String, dynamic>;
    String s(List<String> ks) => ks.map((k) => a[k]).whereType<String>().firstWhere((_) => true, orElse: () => '');
    final iso = (a['ISO3166-2-lvl4'] as String?) ?? '';
    final uf = iso.contains('-') ? iso.split('-').last : (a['state'] as String? ?? '');
    return Endereco(
      rua: s(['road', 'pedestrian', 'highway']),
      numero: (a['house_number'] as String?) ?? '',
      bairro: s(['suburb', 'neighbourhood', 'quarter', 'city_district']),
      cidade: s(['city', 'town', 'village', 'municipality']),
      estado: uf,
    );
  }

  Future<Endereco?> _google(double lat, double lng) async {
    final key = settings.googleKey;
    if (key.isEmpty) return null;
    final r = await http.get(Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '$lat,$lng', 'language': 'pt-BR', 'key': key,
    })).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    final res = (jsonDecode(r.body)['results'] as List?) ?? [];
    if (res.isEmpty) return null;
    final comps = (res.first['address_components'] as List).cast<Map<String, dynamic>>();
    String get(String type, {bool curto = false}) {
      for (final c in comps) {
        if ((c['types'] as List).contains(type)) return (curto ? c['short_name'] : c['long_name']) as String;
      }
      return '';
    }
    return Endereco(
      rua: get('route'),
      numero: get('street_number'),
      bairro: get('sublocality_level_1').isNotEmpty ? get('sublocality_level_1') : get('sublocality'),
      cidade: get('administrative_area_level_2'),
      estado: get('administrative_area_level_1', curto: true),
    );
  }
}
