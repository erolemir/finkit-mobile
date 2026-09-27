import 'package:flutter/material.dart';

import '../api_client.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _fields = <String, TextEditingController>{
    for (final key in [
      'full_name',
      'email',
      'phone_number',
      'password',
      'confirm',
      'tckn',
      'office_name',
      'tax_office',
      'tax_number',
      'iban',
      'advisor_unique_id',
      'company_title',
      'tax_no',
      'city',
      'district',
    ])
      key: TextEditingController(),
  };
  final _errors = <String, String>{};
  String _role = 'CLIENT';
  int _step = 0;
  bool _accepted = false;
  bool _busy = false;
  bool _registered = false;
  String? _message;

  String _value(String key) => _fields[key]!.text.trim();

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _fields[key],
      obscureText: secret,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, errorText: _errors[key]),
      onChanged: (_) => setState(() => _errors.remove(key)),
    ),
  );

  bool _validate() {
    _errors.clear();
    if (_step == 0) {
      if (_value('full_name').isEmpty)
        _errors['full_name'] = 'Ad soyad gerekli';
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_value('email'))) {
        _errors['email'] = 'Geçerli e-posta girin';
      }
      if (_value('password').length < 10)
        _errors['password'] = 'En az 10 karakter girin';
      if (_value('password') != _value('confirm'))
        _errors['confirm'] = 'Şifreler eşleşmiyor';
      if (_role == 'CLIENT' && !RegExp(r'^\d{11}$').hasMatch(_value('tckn'))) {
        _errors['tckn'] = '11 haneli TCKN girin';
      }
    } else if (_step == 1) {
      if (_role == 'ADVISOR') {
        for (final key in ['office_name', 'tax_office', 'tax_number', 'iban']) {
          if (_value(key).isEmpty) _errors[key] = 'Bu alan gerekli';
        }
      } else {
        if (_value('advisor_unique_id').isEmpty) {
          _errors['advisor_unique_id'] = 'Müşavir kodu gerekli';
        }
        if (_value('company_title').isEmpty)
          _errors['company_title'] = 'Şirket ünvanı gerekli';
      }
    } else {
      if (_value('city').isEmpty) _errors['city'] = 'İl gerekli';
      if (_value('district').isEmpty) _errors['district'] = 'İlçe gerekli';
      if (!_accepted)
        _errors['consent'] = 'Aydınlatma metnini okuyup onaylayın';
    }
    setState(() {});
    return _errors.isEmpty;
  }

  Future<void> _continue() async {
    if (_busy || !_validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_step < 2) {
        final check = await widget.api.registrationPrecheck({
          'role': _role,
          'email': _value('email'),
          if (_value('phone_number').isNotEmpty)
            'phone_number': _value('phone_number'),
          if (_role == 'CLIENT') ...{
            'tckn': _value('tckn'),
            if (_step == 1) 'advisor_unique_id': _value('advisor_unique_id'),
            if (_step == 1 && _value('tax_no').isNotEmpty)
              'tax_no': _value('tax_no'),
          } else if (_step == 1) ...{
            'tax_number': _value('tax_number'),
            'iban': _value('iban'),
          },
        });
        if (check['valid'] != true) {
          final raw = check['errors'];
          if (raw is Map) {
            setState(() {
              for (final entry in raw.entries) {
                _errors['${entry.key}'] = '${entry.value}';
              }
            });
          }
          return;
        }
        if (mounted) setState(() => _step++);
      } else {
        final common = <String, dynamic>{
          'full_name': _value('full_name'),
          'email': _value('email'),
          'password': _value('password'),
          'city': _value('city'),
          'district': _value('district'),
          'address': '${_value('city')} / ${_value('district')}',
          if (_value('phone_number').isNotEmpty)
            'phone_number': _value('phone_number'),
        };
        await widget.api.registerAccount(_role, {
          ...common,
          if (_role == 'ADVISOR') ...{
            'office_name': _value('office_name'),
            'tax_office': _value('tax_office'),
            'tax_number': _value('tax_number'),
            'iban': _value('iban'),
          } else ...{
            'advisor_unique_id': _value('advisor_unique_id'),
            'company_title': _value('company_title'),
            'tckn': _value('tckn'),
            if (_value('tax_no').isNotEmpty) 'tax_no': _value('tax_no'),
          },
        });
        if (mounted) setState(() => _registered = true);
      }
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPrivacy() => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('KVKK Aydınlatma Metni'),
      content: const SingleChildScrollView(
        child: Text(
          '''6698 Sayılı KVKK Kapsamında Aydınlatma Metni

1. Veri Sorumlusu
Finkit Mali Müşavirlik Platformu ("Platform") olarak, 6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında veri sorumlusu sıfatıyla kişisel verilerinizi aşağıda açıklanan amaçlar doğrultusunda ve KVKK'nın belirlediği ilkelere uygun olarak işlemekteyiz.

2. İşlenen Kişisel Veriler
Kimlik Bilgileri: Ad-soyad, T.C. Kimlik Numarası (TCKN)
İletişim Bilgileri: E-posta adresi, telefon numarası
Mali Bilgiler: Vergi numarası, vergi dairesi, IBAN, şirket ünvanı
Hesap Bilgileri: Kullanıcı adı, şifre (şifreli olarak saklanır), kullanıcı rolü
İşlem Bilgileri: Ödeme kayıtları, belge yükleme geçmişi, platform kullanım verileri

3. Kişisel Verilerin İşlenme Amaçları
Mali müşavirlik hizmetlerinin yürütülmesi ve mükellef-müşavir ilişkisinin sağlanması; kullanıcı hesabının oluşturulması ve yönetilmesi; vergisel belge ve dökümanların güvenli şekilde saklanması ve paylaşılması; ödeme takip ve hatırlatma hizmetlerinin sunulması; platform içi iletişim ve bildirim hizmetlerinin sağlanması; yasal yükümlülüklerin yerine getirilmesi; platform güvenliğinin sağlanması ve hizmet kalitesinin artırılması.

4. Kişisel Verilerin Aktarılması
Kişisel verileriniz; yasal yükümlülükler kapsamında yetkili kamu kurum ve kuruluşlarına, hizmetlerin sunulması amacıyla iş ortaklarımıza ve teknik altyapı sağlayıcılarımıza, ödeme işlemlerinin gerçekleştirilmesi amacıyla ilgili finansal kuruluşlara ve mali müşavir-mükellef ilişkisi kapsamında ilgili mali müşavirinize aktarılabilmektedir.

5. Kişisel Verilerin Saklanma Süresi
Kişisel verileriniz, işlenme amaçlarının gerektirdiği süre boyunca ve ilgili mevzuatta öngörülen zamanaşımı süreleri boyunca saklanmaktadır.

6. Veri Sahibinin Hakları (KVKK Madde 11)
Kişisel verilerinizin işlenip işlenmediğini öğrenme; işlenmişse buna ilişkin bilgi talep etme; işlenme amacını ve buna uygun kullanılıp kullanılmadığını öğrenme; eksik veya yanlış işlenmiş verilerin düzeltilmesini isteme; KVKK'nın 7. maddesinde öngörülen şartlar çerçevesinde silinmesini veya yok edilmesini isteme.

7. Başvuru Yöntemi
Haklarınızı kullanmak için Platform üzerindeki iletişim kanalları aracılığıyla başvurabilirsiniz. Başvurunuz en geç 30 gün içinde sonuçlandırılacaktır.

Bu aydınlatma metni, 6698 sayılı KVKK'nın 10. maddesi uyarınca bilgilendirme amacıyla hazırlanmıştır.''',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Kapat'),
        ),
        FilledButton(
          onPressed: () {
            setState(() => _accepted = true);
            Navigator.pop(dialogContext);
          },
          child: const Text('Okudum, Kabul Ediyorum'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hesap Aç')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: _registered
            ? [
                const Icon(Icons.mark_email_read_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Doğrulama bağlantısı ${_value('email')} adresine gönderildi.',
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await widget.api.resendVerification(_value('email'));
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Doğrulama e-postası gönderildi.'),
                          ),
                        );
                    } catch (error) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$error')));
                    }
                  },
                  child: const Text('Bağlantıyı Yeniden Gönder'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Girişe Dön'),
                ),
              ]
            : [
                Text(
                  'Adım ${_step + 1} / 3',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (_step == 0) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Hesap Türü'),
                    items: const [
                      DropdownMenuItem(
                        value: 'CLIENT',
                        child: Text('Mükellef'),
                      ),
                      DropdownMenuItem(
                        value: 'ADVISOR',
                        child: Text('Müşavir'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _role = value ?? 'CLIENT'),
                  ),
                  const SizedBox(height: 12),
                  _field('full_name', 'Ad Soyad'),
                  _field(
                    'email',
                    'E-posta',
                    keyboard: TextInputType.emailAddress,
                  ),
                  _field(
                    'phone_number',
                    'Telefon (opsiyonel)',
                    keyboard: TextInputType.phone,
                  ),
                  if (_role == 'CLIENT')
                    _field(
                      'tckn',
                      'TC Kimlik No',
                      keyboard: TextInputType.number,
                    ),
                  _field('password', 'Şifre', secret: true),
                  _field('confirm', 'Şifre Tekrar', secret: true),
                ],
                if (_step == 1 && _role == 'ADVISOR') ...[
                  _field('office_name', 'Ofis Adı'),
                  _field('tax_office', 'Vergi Dairesi'),
                  _field(
                    'tax_number',
                    'Vergi Numarası',
                    keyboard: TextInputType.number,
                  ),
                  _field('iban', 'IBAN'),
                ],
                if (_step == 1 && _role == 'CLIENT') ...[
                  _field('advisor_unique_id', 'Müşavir Kodu'),
                  _field('company_title', 'Şirket Ünvanı'),
                  _field(
                    'tax_no',
                    'Vergi Numarası (opsiyonel)',
                    keyboard: TextInputType.number,
                  ),
                ],
                if (_step == 2) ...[
                  _field('city', 'İl'),
                  _field('district', 'İlçe'),
                  CheckboxListTile(
                    value: _accepted,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('KVKK aydınlatma metnini okudum'),
                    onChanged: (value) =>
                        setState(() => _accepted = value == true),
                  ),
                  TextButton(
                    onPressed: _showPrivacy,
                    child: const Text('Aydınlatma Metnini Oku'),
                  ),
                  if (_errors['consent'] != null)
                    Text(
                      _errors['consent']!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _step--),
                        child: const Text('Geri'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _busy ? null : _continue,
                      child: Text(
                        _busy
                            ? 'İşleniyor…'
                            : _step == 2
                            ? 'Hesap Aç'
                            : 'Devam Et',
                      ),
                    ),
                  ],
                ),
              ],
      ),
    ),
  );
}
