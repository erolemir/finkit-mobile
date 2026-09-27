import 'package:flutter/material.dart';

import '../api_client.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.api, required this.token});
  final FinkitApi api;
  final String token;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    if (widget.token.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Doğrulama bağlantısı geçersiz.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.verifyEmailToken(widget.token);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('E-posta Doğrulama')),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const CircularProgressIndicator()
              else ...[
                Icon(
                  _error == null
                      ? Icons.verified_outlined
                      : Icons.error_outline,
                  size: 48,
                  color: _error == null
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'E-posta adresiniz doğrulandı. Hesap onayı gerekiyorsa başvurunuz inceleniyor.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/');
                    }
                  },
                  child: const Text('Giriş Ekranına Dön'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
