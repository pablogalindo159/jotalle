import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<List<String>> _fotosManuais() async {
    final fotos = <String>[];
    final picker = ImagePicker();
    while (mounted) {
      final x = await picker.pickImage(source: ImageSource.camera, maxWidth: 2200, imageQuality: 90);
      if (x == null) break;
      fotos.add(x.path);
      if (!mounted) break;
      final outra = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('${fotos.length} página(s)'),
          content: const Text('Adicionar outra página?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CONCLUIR')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('OUTRA PÁGINA')),
          ],
        ),
      );
      if (outra != true) break;
    }
    return fotos;
  }

  Future<void> _digitalizar() async {
    setState(() { _msg = null; _pdf = null; });
    List<String>? paginas;
    try {
      paginas = await CunningDocumentScanner.getPictures(noOfPages: 30, isGalleryImportAllowed: true);
    } catch (_) {
      // scanner do Google indisponível neste aparelho: usa a câmera comum, página por página
      paginas = await _fotosManuais();
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
      final copia = await arq.copy('${(await getTemporaryDirectory()).path}/Jotalle_documento_$id.pdf');

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
      await widget.fila.enviarTudo().timeout(const Duration(seconds: 90), onTimeout: () => 0);
      final st = widget.fila.status(id);
      final n = paginas.length;

      if (st == EnvioStatus.enviado) {
        if (!mounted) return;
        final zap = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle, size: 48, color: Colors.green),
            title: const Text('Enviado com sucesso!', textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(paginas.first), height: 220, width: double.infinity, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text('O PDF ($n página(s)) foi salvo no servidor.', textAlign: TextAlign.center),
              ]),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsOverflowDirection: VerticalDirection.down,
            actions: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.send),
                label: const Text('Enviar pelo WhatsApp'),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Fechar')),
            ],
          ),
        );
        if (zap == true) await Share.shareXFiles([XFile(copia.path)], text: 'Documento Jotalle');
        if (mounted) Navigator.pop(context); // volta para a tela inicial
      } else {
        // Não foi para o servidor: guarda uma cópia para abrir/salvar no celular.
        final dl = File('${(await getApplicationDocumentsDirectory()).path}/documento_${agora.millisecondsSinceEpoch}.pdf');
        await arq.copy(dl.path);

        // Salva sozinho as páginas digitalizadas (imagens) na galeria do celular.
        var salvou = true;
        for (final p in paginas) {
          try {
            await Gal.putImage(p, album: 'Jotalle').timeout(const Duration(seconds: 15));
          } catch (_) {
            salvou = false;
          }
        }
        setState(() {
          _pdf = dl;
          _msg = (st == EnvioStatus.rejeitado
                  ? 'Não foi enviado: o servidor recusou (${widget.fila.rejeitados[id]}).'
                  : 'Não foi enviado: sem conexão. O PDF ($n página(s)) ficou na fila e será enviado quando houver internet.') +
              (salvou
                  ? '\n\nAs páginas foram salvas na galeria do celular. Você também pode abrir o PDF ou enviar pelo WhatsApp abaixo.'
                  : '\n\nNão foi possível salvar na galeria. Abra o PDF ou envie pelo WhatsApp abaixo.');
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
