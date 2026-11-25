import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../services/location_service.dart';
import '../services/settings.dart';
import '../services/upload_queue.dart';

/// Digitaliza páginas (detecção de bordas), junta em um PDF, guarda no aparelho e envia ao servidor.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.settings, required this.fila});
  final Settings settings;
  final UploadQueue fila;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _motorista = TextEditingController();
  final _placa = TextEditingController();
  bool _gerando = false;
  String? _msg;
  File? _pdf;

  Future<void> _digitalizar() async {
    setState(() { _msg = null; _pdf = null; });
    List<String>? paginas;
    try {
      paginas = await CunningDocumentScanner.getPictures(noOfPages: 30, isGalleryImportAllowed: true);
    } catch (e) {
      setState(() => _msg = 'Não foi possível abrir o scanner: $e');
      return;
    }
    if (paginas == null || paginas.isEmpty) return;

    setState(() => _gerando = true);
    try {
      final agora = DateTime.now();
      LocalFix? local;
      try {
        local = await LocationService(widget.settings).obter();
      } catch (_) {}

      final doc = pw.Document();
      for (final p in paginas) {
        final img = pw.MemoryImage(await File(p).readAsBytes());
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
        ));
      }

      final id = const Uuid().v4();
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/fila')..createSync(recursive: true);
      final arq = File('${dir.path}/$id.pdf');
      await arq.writeAsBytes(await doc.save());

      final placa = _placa.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      await widget.fila.adicionar(UploadItem({
        'device_uuid': id,
        'tipo': 'documento',
        'motorista': _motorista.text.trim().toUpperCase(),
        'placa_cavalo': placa,
        'tirado_em': agora.toIso8601String(),
        'rua': local?.endereco.ruaNum,
        'bairro': local?.endereco.bairro,
        'cidade': local?.endereco.cidade,
        'estado': local?.endereco.estado,
        'endereco': local?.endereco.linha,
        'latitude': local?.lat,
        'longitude': local?.lng,
      }, arq.path));
      await widget.fila.enviarTudo();
      final st = widget.fila.status(id);
      final n = paginas.length;

      if (st == EnvioStatus.enviado) {
        setState(() => _msg = 'Enviado com sucesso! PDF ($n página(s)) salvo no servidor ✓');
      } else {
        // Não foi para o servidor: guarda uma cópia para abrir/salvar no celular.
        final dl = File('${(await getApplicationDocumentsDirectory()).path}/documento_${agora.millisecondsSinceEpoch}.pdf');
        await arq.copy(dl.path);
        setState(() {
          _pdf = dl;
          _msg = st == EnvioStatus.rejeitado
              ? 'Não foi enviado: o servidor recusou (${widget.fila.rejeitados[id]}). Abra o PDF abaixo e salve no celular.'
              : 'Não foi enviado: sem conexão. O PDF ($n página(s)) ficou na fila e será enviado quando houver internet. Abra abaixo para salvar no celular.';
        });
      }
    } catch (e) {
      setState(() => _msg = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Digitalizar documento')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextField(
              controller: _motorista,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Motorista (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _placa,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Placa do cavalo (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _gerando ? null : _digitalizar,
              icon: _gerando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.document_scanner),
              label: Text(_gerando ? 'Gerando e enviando…' : 'Tirar foto do documento'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: const Color(0xFF2E7D32)),
            ),
            if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg!)),
            if (_pdf != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton.icon(
                  onPressed: () => OpenFilex.open(_pdf!.path),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Abrir / baixar PDF'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ),
            if (_pdf != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: () => Share.shareXFiles([XFile(_pdf!.path)], text: 'Documento Jotalle'),
                  icon: const Icon(Icons.send),
                  label: const Text('Enviar pelo WhatsApp'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: const Color(0xFF25D366)),
                ),
              ),
          ]),
        ),
      );
}
