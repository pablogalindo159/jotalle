import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'settings.dart';

class Endereco {
  Endereco({this.rua = '', this.bairro = '', this.cidade = '', this.estado = ''});
  final String rua, bairro, cidade, estado;

  String get linha => [rua, bairro, cidade, estado].where((e) => e.isNotEmpty).join(', ');
  bool get vazio => linha.isEmpty;
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
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
    );
    final end = await _endereco(pos.latitude, pos.longitude);
    return LocalFix(pos.latitude, pos.longitude, end);
  }

  Future<Endereco> _endereco(double lat, double lng) async {
    final ordem = settings.mapa == MapaProvedor.google
        ? [_google, _osm]
        : [_osm, _google];
    for (final f in ordem) {
      try {
        final e = await f(lat, lng).timeout(const Duration(seconds: 10));
        if (e != null && !e.vazio) return e;
      } catch (_) {}
    }
    return Endereco();
  }

  Future<Endereco?> _osm(double lat, double lng) async {
    final r = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2', 'lat': '$lat', 'lon': '$lng', 'addressdetails': '1', 'accept-language': 'pt-BR',
      }),
      headers: {'User-Agent': kUserAgent},
    );
    if (r.statusCode != 200) return null;
    final a = (jsonDecode(r.body)['address'] ?? {}) as Map<String, dynamic>;
    String s(List<String> ks) => ks.map((k) => a[k]).whereType<String>().firstWhere((_) => true, orElse: () => '');
    final iso = (a['ISO3166-2-lvl4'] as String?) ?? '';
    final uf = iso.contains('-') ? iso.split('-').last : (a['state'] as String? ?? '');
    final rua = s(['road', 'pedestrian', 'highway']);
    final num = a['house_number'] as String?;
    return Endereco(
      rua: num != null && rua.isNotEmpty ? '$rua, $num' : rua,
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
    }));
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
    final num = get('street_number');
    final rua = get('route');
    return Endereco(
      rua: num.isNotEmpty && rua.isNotEmpty ? '$rua, $num' : rua,
      bairro: get('sublocality_level_1').isNotEmpty ? get('sublocality_level_1') : get('sublocality'),
      cidade: get('administrative_area_level_2'),
      estado: get('administrative_area_level_1', curto: true),
    );
  }
}
