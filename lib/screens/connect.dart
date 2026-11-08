import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import '../xtream.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_server.text.trim().isEmpty || _username.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Fill in all three fields.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).connect(
        XtreamCredentials(server: _server.text, username: _username.text.trim(), password: _password.text),
      );
    } on XtreamException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn’t connect: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
          child: Container(
            width: 400,
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
            decoration: BoxDecoration(
              color: p.raised,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.line),
              boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 48, offset: Offset(0, 24))],
            ),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(size: 40),
                const SizedBox(height: 24),
                const Text('Connect your provider',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.65, height: 1.15)),
                const SizedBox(height: 10),
                const Text('Enter your Xtream Codes details. They stay on this computer.',
                    style: TextStyle(fontSize: 14, height: 1.55, color: Palette.muted)),
                const SizedBox(height: 28),
                _Field(label: 'Server URL', controller: _server, hint: 'http://example.com:8080', autofocus: true, keyboard: TextInputType.url),
                const SizedBox(height: 16),
                _Field(label: 'Username', controller: _username, autofill: AutofillHints.username),
                const SizedBox(height: 16),
                _Field(label: 'Password', controller: _password, obscure: true, autofill: AutofillHints.password, onSubmit: _connect),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(fontSize: 13, color: p.accent, height: 1.4)),
                ],
                const SizedBox(height: 28),
                PrimaryPill(label: 'Connect', trailingIcon: Icons.arrow_forward_rounded, onPressed: _connect, busy: _busy, height: 46, expand: true),
                const SizedBox(height: 14),
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline_rounded, size: 13, color: Palette.dim),
                  SizedBox(width: 8),
                  Text('Saved in your system keychain', style: TextStyle(fontSize: 12, color: Palette.dim)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.hint, this.obscure = false, this.autofocus = false, this.autofill, this.keyboard, this.onSubmit});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure, autofocus;
  final String? autofill;
  final TextInputType? keyboard;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.24, color: Palette.muted)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: autofocus,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: keyboard,
        autofillHints: autofill == null ? null : [autofill!],
        textInputAction: onSubmit == null ? TextInputAction.next : TextInputAction.done,
        onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: p.surface,
          hintText: hint,
          hintStyle: const TextStyle(color: Palette.faint, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: border(Colors.transparent),
          focusedBorder: border(p.ring),
        ),
      ),
    ]);
  }
}
