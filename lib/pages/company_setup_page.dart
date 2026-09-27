import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });
  final FinkitApi api;
  final VoidCallback onAuthenticated;

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _fields = <String, TextEditingController>{
    for (final key in const [
      'full_name',
      'email',
      'phone_number',
      'tckn',
      'password',
      'password_confirm',
      'city',
      'district',
      'message',
    ])
      key: TextEditingController(),
  };
  int _step = 1;
  int _page = 1;
  Map<String, dynamic>? _selectedAdvisor;
  List<Map<String, dynamic>> _advisors = [];
  int _total = 0;
  bool _busy = false;
  bool _registered = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _fields[key]!.text.trim();

  String? _stepOneError() {
    if (_value('full_name').isEmpty) return 'Ad soyad girin.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_value('email'))) {
      return 'Geçerli e-posta adresi girin.';
    }
    if (_value('tckn').isNotEmpty &&
        !RegExp(r'^\d{11}$').hasMatch(_value('tckn'))) {
      return 'TC kimlik numarası 11 haneli olmalı.';
    }
    final password = _fields['password']!.text;
    if (password.length < 10 ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password) ||
        !RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(password)) {
      return 'Şifre en az 10 karakter, büyük/küçük harf, rakam ve özel karakter içermeli.';
    }
    if (password != _fields['password_confirm']!.text) {
      return 'Şifreler eşleşmiyor.';
    }
    return null;
  }

  Future<void> _search([int page = 1]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.publicAdvisors(
        city: _value('city'),
        district: _value('district'),
        page: page,
      );
      if (!mounted) return;
      final raw = result['items'];
      setState(() {
        _advisors = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _total = int.tryParse('${result['total']}') ?? _advisors.length;
        _page = page;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    final error = _stepOneError();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _step = 2;
      _error = null;
    });
    _search();
  }

  Future<void> _register() async {
    final advisor = _selectedAdvisor;
    if (_busy || advisor == null) {
      setState(() => _error = 'Önce bir müşavir seçin.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Şirket Açma Başvurusu'),
        content: Text(
          '${advisor['full_name']} müşavirine bağlantı isteği gönderilecek. Hesabınız oluşturulup ödeme ve müşavir onayı beklenecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Başvuruyu Gönder'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.registerCompanySetup({
        'email': _value('email'),
        'password': _fields['password']!.text,
        'full_name': _value('full_name'),
        if (_value('phone_number').isNotEmpty)
          'phone_number': _value('phone_number'),
        if (_value('tckn').isNotEmpty) 'tckn': _value('tckn'),
        'advisor_user_id': advisor['user_id'],
        if (_value('message').isNotEmpty) 'message': _value('message'),
      });
      await widget.api.adoptRegistrationSession(result, email: _value('email'));
      if (mounted) setState(() => _registered = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {bool secret = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _fields[key],
      obscureText: secret,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Şirket Aç')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: _registered
          ? [
              const PageTitle(
                title: 'Başvurunuz Alındı',
                subtitle: 'E-posta doğrulaması, abonelik ödemesi ve müşavir bağlantı onayı bekleniyor.',
              ),
              FilledButton(
                onPressed: widget.onAuthenticated,
                child: const Text('Ödemelerime Git'),
              ),
            ]
          : [
              PageTitle(
                title: _step == 1 ? 'Kişisel Bilgiler' : 'Müşavir Seçimi',
                subtitle: 'Şirket açma başvurusu · $_step/2',
              ),
              if (_step == 1) ...[
                _field('full_name', 'Ad soyad'),
                _field('email', 'E-posta'),
                _field('phone_number', 'Telefon'),
                _field('tckn', 'TC kimlik numarası (isteğe bağlı)'),
                _field('password', 'Şifre', secret: true),
                _field('password_confirm', 'Şifre tekrar', secret: true),
                FilledButton(
                  onPressed: _next,
                  child: const Text('Müşavir Seçimine Geç'),
                ),
              ] else ...[
                _field('city', 'İl'),
                _field('district', 'İlçe'),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _search(),
                  icon: const Icon(Icons.search),
                  label: const Text('Müşavir Ara'),
                ),
                if (_busy) const LoadingState(),
                if (!_busy && _advisors.isEmpty)
                  const Text('Bu aramada müşavir bulunamadı.'),
                for (final advisor in _advisors)
                  Card(
                    child: RadioListTile<int>(
                      value: int.tryParse('${advisor['user_id']}') ?? 0,
                      groupValue: int.tryParse(
                        '${_selectedAdvisor?['user_id']}',
                      ),
                      onChanged: (_) =>
                          setState(() => _selectedAdvisor = advisor),
                      title: Text('${advisor['full_name']}'),
                      subtitle: Text(
                        '${advisor['office_name'] ?? ''} · ${advisor['city'] ?? ''} ${advisor['district'] ?? ''}',
                      ),
                    ),
                  ),
                if (_total > 12)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _busy || _page <= 1
                            ? null
                            : () => _search(_page - 1),
                        child: const Text('Önceki'),
                      ),
                      Text('$_page / ${(_total / 12).ceil()}'),
                      TextButton(
                        onPressed: _busy || _page * 12 >= _total
                            ? null
                            : () => _search(_page + 1),
                        child: const Text('Sonraki'),
                      ),
                    ],
                  ),
                _field('message', 'Müşavire not (isteğe bağlı)'),
                FilledButton(
                  onPressed: _busy ? null : _register,
                  child: const Text('Başvuruyu Tamamla'),
                ),
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('Geri'),
                ),
              ],
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
            ],
    ),
  );
}
