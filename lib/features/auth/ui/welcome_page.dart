import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/anime_sparkles.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_card.dart';
import '../logic/auth_store.dart';

/// Primera vez: bienvenida + creación del perfil local.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  String _sex = 'F';
  bool _hide = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _user, _pass, _pass2, _weight, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthStore>().register(
            name: _name.text,
            username: _user.text,
            password: _pass.text,
            weightKg: _num(_weight.text)!,
            heightCm: _num(_height.text)!,
            sex: _sex,
          );
    } catch (_) {
      if (mounted) showFlash(context, 'No se pudo guardar el perfil.', kind: FlashKind.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          Container(height: 560, decoration: const BoxDecoration(gradient: Palette.night)),
          const Positioned(left: 0, right: 0, top: 0, height: 560, child: AnimeSparkles(count: 26)),
          Positioned(
            right: -60,
            top: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.lilac.withValues(alpha: 0.16),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, top + 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const MascotAvatar(size: 52),
                    const SizedBox(width: 14),
                    const Text(
                      'Amatista',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Entrena con tus sensores,\nprotegido con tu huella y tu rostro.',
                  style: TextStyle(color: Palette.lilacSoft, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Image.asset(
                    Palette.mascotStronger,
                    height: 280,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stack) => const SizedBox(height: 20),
                  ),
                ),
                const SizedBox(height: 14),
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Crea tu perfil',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Se guarda solo en este teléfono.',
                          style: TextStyle(color: Palette.inkMuted),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.badge_rounded),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length < 3) ? 'Escribe tu nombre' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _user,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.length < 4) return 'Mínimo 4 caracteres';
                            if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(t)) {
                              return 'Solo letras, números, punto y guion bajo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass,
                          obscureText: _hide,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Contraseña de respaldo',
                            prefixIcon: const Icon(Icons.key_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hide = !_hide),
                              icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            ),
                          ),
                          validator: (v) {
                            final t = v ?? '';
                            if (t.length < 8) return 'Mínimo 8 caracteres';
                            if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) {
                              return 'Combina letras y números';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pass2,
                          obscureText: _hide,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                          validator: (v) => v != _pass.text ? 'Las contraseñas no coinciden' : null,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Datos corporales',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sirven para estimar tu zancada y las calorías.',
                          style: TextStyle(color: Palette.inkMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _weight,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Peso (kg)',
                                  prefixIcon: Icon(Icons.monitor_weight_rounded),
                                ),
                                validator: (v) {
                                  final n = _num(v ?? '');
                                  return (n == null || n < 25 || n > 300) ? '25 a 300' : null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _height,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Estatura (cm)',
                                  prefixIcon: Icon(Icons.height_rounded),
                                ),
                                validator: (v) {
                                  final n = _num(v ?? '');
                                  return (n == null || n < 100 || n > 250) ? '100 a 250' : null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 14),
                            for (final (code, label) in const [('F', 'Mujer'), ('M', 'Hombre')]) ...[
                              ChoiceChip(
                                label: Text(label),
                                selected: _sex == code,
                                showCheckmark: false,
                                labelStyle: TextStyle(
                                  color: _sex == code ? Colors.white : Palette.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) => setState(() => _sex = code),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          label: 'Crear mi perfil',
                          icon: Icons.arrow_forward_rounded,
                          loading: _saving,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
