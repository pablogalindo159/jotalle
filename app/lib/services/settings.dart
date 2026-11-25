import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

enum MapaProvedor { osm, google }

class Settings {
  Settings._(this._p);
  final SharedPreferences _p;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  String get apiUrl => _p.getString('apiUrl') ?? kApiBaseUrlPadrao;
  set apiUrl(String v) => _p.setString('apiUrl', v.trim().replaceAll(RegExp(r'/+$'), ''));

  String get apiKey => _p.getString('apiKey') ?? '';
  set apiKey(String v) => _p.setString('apiKey', v.trim());

  String get googleKey => _p.getString('googleKey') ?? '';
  set googleKey(String v) => _p.setString('googleKey', v.trim());

  MapaProvedor get mapa => _p.getString('mapa') == 'google' ? MapaProvedor.google : MapaProvedor.osm;
  set mapa(MapaProvedor v) => _p.setString('mapa', v.name);

  String get ultimoMotorista => _p.getString('ultimoMotorista') ?? '';
  set ultimoMotorista(String v) => _p.setString('ultimoMotorista', v);

  String get ultimaPlaca => _p.getString('ultimaPlaca') ?? '';
  set ultimaPlaca(String v) => _p.setString('ultimaPlaca', v);

  String get ultimaCarreta => _p.getString('ultimaCarreta') ?? '';
  set ultimaCarreta(String v) => _p.setString('ultimaCarreta', v);

  SharedPreferences get raw => _p;
}
