import 'package:flutter/material.dart';
import '../services/settings.dart';
import '../services/upload_queue.dart';
import 'photo_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.fila});
  final Settings settings;
  final UploadQueue fila;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _enviando = false;

  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => tela));
    if (mounted) setState(() {});
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final n = await widget.fila.enviarTudo();
    if (!mounted) return;
    setState(() => _enviando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n > 0 ? '$n arquivo(s) enviado(s).' : (widget.fila.pendentes().isEmpty ? 'Nada pendente.' : 'Sem conexão com o servidor.'))));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pend = widget.fila.pendentes().length;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A2A55), Color(0xFF061A38)]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Image.asset('assets/logo.png', width: 200),
                const SizedBox(height: 22),
                Expanded(
                child: _Botao(
                  icone: Icons.photo_camera,
                  texto: 'FOTO',
                  cor: const Color(0xFF3D8BD4),
                  cor2: const Color(0xFF2F74B8),
                  onTap: () => _abrir(PhotoScreen(settings: widget.settings, fila: widget.fila)),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _Botao(
                  icone: Icons.document_scanner,
                  texto: 'DIGITALIZAR\nDOCUMENTO',
                  cor: const Color(0xFF3B9A5A),
                  cor2: const Color(0xFF2E7D46),
                  onTap: () => _abrir(ScanScreen(settings: widget.settings, fila: widget.fila)),
                ),
              ),
              if (pend > 0) ...[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _enviando ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload),
                  label: Text('$pend pendente(s) — enviar agora'),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({required this.icone, required this.texto, required this.cor, required this.cor2, required this.onTap});
  final IconData icone;
  final String texto;
  final Color cor;
  final Color cor2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [cor, cor2]),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 72, color: Colors.white),
                const SizedBox(height: 12),
                Text(texto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        ),
      );
}
