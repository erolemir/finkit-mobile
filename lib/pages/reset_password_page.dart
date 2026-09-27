import 'package:flutter/material.dart';

import '../api_client.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.api,
    required this.token,
    required this.role,
  });

  final FinkitApi api;
  final String token;
  final String role;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (widget.token.isEmpty) {
      setState(() => _error = 'Şifre sıfırlama bağlantısı geçersiz.');
      return;
    }
    if (_password.text.length < 10) {
      setState(() => _error = 'Yeni şifre en az 10 karakter olmalı.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Şifreler eşleşmiyor.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.resetPassword(widget.token, _password.text);
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Şifre Sıfırla')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: _done
              ? [
                  const Icon(Icons.check_circle_outline, size: 54),
                  const SizedBox(height: 16),
                  const Text(
                    'Şifreniz güncellendi. Yeni şifrenizle giriş yapabilirsiniz.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Giriş Ekranına Dön'),
                  ),
                ]
              : [
                  const Text(
                    'Yeni Şifre',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.role == 'CLIENT'
                        ? 'Mükellef hesabı'
                        : 'Müşavir hesabı',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Yeni şifre (en az 10 karakter)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Yeni şifre tekrar',
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Güncelleniyor…' : 'Şifreyi Güncelle'),
                  ),
                ],
        ),
      ),
    ),
  );
}
