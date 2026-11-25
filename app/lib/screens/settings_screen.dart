import 'package:flutter/material.dart';
import '../services/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final Settings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _url = TextEditingController(text: widget.settings.apiUrl);
  late final _key = TextEditingController(text: widget.settings.apiKey);
  late final _gkey = TextEditingController(text: widget.settings.googleKey);
  late MapaProvedor _mapa = widget.settings.mapa;

  void _salvar() {
    widget.settings
      ..apiUrl = _url.text
      ..apiKey = _key.text
      ..googleKey = _gkey.text
      ..mapa = _mapa;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Configurações')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL do servidor', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          TextField(controller: _key, decoration: const InputDecoration(labelText: 'Chave da API (se o servidor exigir)', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          const Text('Mapa e endereço', style: TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<MapaProvedor>(
              title: const Text('OpenStreetMap (padrão, grátis)'), value: MapaProvedor.osm, groupValue: _mapa, onChanged: (v) => setState(() => _mapa = v!)),
          RadioListTile<MapaProvedor>(
              title: const Text('Google Maps (precisa de chave)'), value: MapaProvedor.google, groupValue: _mapa, onChanged: (v) => setState(() => _mapa = v!)),
          TextField(controller: _gkey, decoration: const InputDecoration(labelText: 'Chave Google Maps (Static Maps + Geocoding)', border: OutlineInputBorder())),
          const SizedBox(height: 24),
          FilledButton(onPressed: _salvar, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Salvar')),
        ]),
      );
}
