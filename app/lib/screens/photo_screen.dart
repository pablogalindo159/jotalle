import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/location_service.dart';
import '../services/map_service.dart';
import '../services/settings.dart';
import '../services/stamp_service.dart';
import '../services/upload_queue.dart';

class PhotoScreen extends StatefulWidget {
  const PhotoScreen({super.key, required this.settings, required this.fila});
  final Settings settings;
  final UploadQueue fila;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final _form = GlobalKey<FormState>();
  late final _motorista = TextEditingController(text: widget.settings.ultimoMotorista);
  late final _placa = TextEditingController(text: widget.settings.ultimaPlaca);
  late final _carreta = TextEditingController(text: widget.settings.ultimaCarreta);
  final _picker = ImagePicker();

  File? _principal, _extra;
  DateTime? _quando;
  Future<LocalFix>? _fix;
  bool _gerando = false;
  String? _aviso;

  static String _limpa(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<File?> _tirar() async {
    final x = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 92);
    return x == null ? null : File(x.path);
  }

  Future<void> _fotoPrincipal() async {
    if (!_form.currentState!.validate()) return;
    // começa a buscar GPS/endereço enquanto a câmera abre
    _fix = LocationService(widget.settings).obter();
    final f = await _tirar();
    if (f == null) return;
    setState(() {
      _principal = f;
      _quando = DateTime.now();
    });
  }

  Future<void> _fotoExtra() async {
    final f = await _tirar();
    if (f != null) setState(() => _extra = f);
  }

  Future<void> _gerar() async {
    if (_principal == null || _quando == null) return;
    setState(() { _gerando = true; _aviso = null; });
    try {
      final s = widget.settings;
      final motorista = _motorista.text.trim().toUpperCase();
      final placa = _limpa(_placa.text), carreta = _limpa(_carreta.text);
      s.ultimoMotorista = motorista;
      s.ultimaPlaca = placa;
      s.ultimaCarreta = carreta;

      LocalFix? local;
      try {
        local = await _fix;
      } catch (e) {
        _aviso = '$e (a foto sai sem localização)';
      }

      final mapa = local == null ? null : await MapService(s).gerar(local.lat, local.lng);
      final jpg = await StampService().gerar(
        principal: _principal!,
        extra: _extra,
        mapaPng: mapa,
        dados: StampData(motorista: motorista, placa: placa, carreta: carreta, quando: _quando!, local: local),
      );

      final id = const Uuid().v4();
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/fila')..createSync(recursive: true);
      final arq = File('${dir.path}/$id.jpg');
      await arq.writeAsBytes(jpg);

      await widget.fila.adicionar(UploadItem({
        'device_uuid': id,
        'tipo': 'foto',
        'motorista': motorista,
        'placa_cavalo': placa,
        'placa_carreta': carreta,
        'tirado_em': _quando!.toIso8601String(),
        'rua': local?.endereco.ruaNum,
        'bairro': local?.endereco.bairro,
        'cidade': local?.endereco.cidade,
        'estado': local?.endereco.estado,
        'endereco': local?.endereco.linha,
        'latitude': local?.lat,
        'longitude': local?.lng,
      }, arq.path));
      await widget.fila.enviarTudo();

      // Só guarda no aparelho (galeria) se o envio ficou pendente, ex.: sem internet.
      final pendente = widget.fila.pendentes().any((i) => i.meta['device_uuid'] == id);
      if (pendente) {
        try { await Gal.putImage(arq.path, album: 'Jotalle'); } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text((pendente
                  ? 'Sem conexão: foto salva no aparelho e na fila. Será enviada quando houver internet.'
                  : 'Foto enviada ao sistema ✓') +
              (_aviso != null ? '\n$_aviso' : ''))));
      Navigator.pop(context);
    } catch (e) {
      setState(() => _aviso = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foto')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _motorista,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder()),
                  validator: (v) => (v ?? '').trim().length >= 3 ? null : 'Informe o nome do motorista',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _placa,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(8)],
                  decoration: const InputDecoration(labelText: 'Placa do cavalo (caminhão)', border: OutlineInputBorder()),
                  validator: (v) => _limpa(v ?? '').length == 7 ? null : 'Placa com 7 caracteres',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _carreta,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(8)],
                  decoration: const InputDecoration(
                      labelText: 'Placa da carreta (opcional)', border: OutlineInputBorder()),
                  validator: (v) {
                    final t = _limpa(v ?? '');
                    return t.isEmpty || t.length == 7 ? null : 'Placa com 7 caracteres';
                  },
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _Slot(titulo: 'Foto principal', arquivo: _principal, onTap: _fotoPrincipal)),
              const SizedBox(width: 12),
              Expanded(
                  child: _Slot(
                      titulo: '+ Foto extra (opcional)',
                      arquivo: _extra,
                      onTap: _fotoExtra,
                      onLimpar: _extra == null ? null : () => setState(() => _extra = null))),
            ]),
            if (_aviso != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_aviso!, style: const TextStyle(color: Colors.orange))),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _principal == null || _gerando ? null : _gerar,
              icon: _gerando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_gerando ? 'Gerando e enviando…' : 'Gerar e enviar'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.titulo, required this.arquivo, required this.onTap, this.onLimpar});
  final String titulo;
  final File? arquivo;
  final VoidCallback onTap;
  final VoidCallback? onLimpar;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(16),
              image: arquivo == null ? null : DecorationImage(image: FileImage(arquivo!), fit: BoxFit.cover),
            ),
            child: arquivo == null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.photo_camera, size: 36),
                    const SizedBox(height: 6),
                    Text(titulo, textAlign: TextAlign.center),
                  ])
                : Align(
                    alignment: Alignment.topRight,
                    child: onLimpar == null
                        ? null
                        : IconButton.filled(onPressed: onLimpar, icon: const Icon(Icons.close, size: 18)),
                  ),
          ),
        ),
      );
}
