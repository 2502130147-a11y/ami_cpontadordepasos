import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/widgets/anime_sparkles.dart';
import '../data/face_signature.dart';

enum FaceScanMode { enroll, verify }

class FaceScanResult {
  const FaceScanResult(this.ok, this.message, {this.template});
  final bool ok;
  final String message;
  final FaceTemplate? template;
}

/// Reconocimiento facial propio con la cámara frontal.
///
/// Muchos teléfonos Android no ofrecen el desbloqueo facial a las apps (el
/// diálogo del sistema solo acepta la huella). Por eso el rostro se verifica
/// aquí: ML Kit detecta los contornos de la cara, se compara la forma con la
/// plantilla registrada y se pide una sonrisa como prueba de vida (una foto
/// impresa no puede sonreír).
class FaceScanPage extends StatefulWidget {
  const FaceScanPage({super.key, required this.mode, this.template});

  final FaceScanMode mode;
  final FaceTemplate? template;

  @override
  State<FaceScanPage> createState() => _FaceScanPageState();
}

enum _Stage { starting, face, smile, done }

class _FaceScanPageState extends State<FaceScanPage> with WidgetsBindingObserver {
  static const _samplesNeeded = 5;
  static const _timeout = Duration(seconds: 25);

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.25,
    ),
  );

  CameraController? _cam;
  bool _looping = false;
  bool _finished = false;
  _Stage _stage = _Stage.starting;
  String _hint = 'Encendiendo la cámara…';
  String? _error;
  int? _match;
  final List<List<double>> _samples = [];
  int _goodMatches = 0;
  Timer? _deadline;

  bool get _enroll => widget.mode == FaceScanMode.enroll;

  double get _progress {
    switch (_stage) {
      case _Stage.starting:
        return 0;
      case _Stage.face:
        return _enroll ? 0.7 * _samples.length / _samplesNeeded : 0.35 * _goodMatches / 2;
      case _Stage.smile:
        return _enroll ? 0.8 : 0.6;
      case _Stage.done:
        return 1;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    _deadline = Timer(_timeout, () {
      _finish(false, _enroll
          ? 'Se acabó el tiempo. Busca buena luz y vuelve a intentarlo.'
          : 'No se pudo reconocer tu rostro a tiempo.');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    _looping = false;
    _cam?.dispose();
    _detector.close();
    super.dispose();
  }

  /// La cámara se libera en segundo plano y se vuelve a abrir al regresar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _looping = false;
      final c = _cam;
      _cam = null;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && _cam == null && !_finished) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final ctrl = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await ctrl.initialize();
      try {
        await ctrl.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _cam = ctrl;
        _stage = _Stage.face;
        _hint = _enroll ? 'Coloca tu rostro dentro del círculo' : 'Mira de frente a la cámara';
      });
      _loop();
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir la cámara frontal.');
    }
  }

  Future<void> _loop() async {
    if (_looping) return;
    _looping = true;
    while (_looping && mounted && !_finished) {
      final cam = _cam;
      if (cam == null || !cam.value.isInitialized) break;
      try {
        final shot = await cam.takePicture();
        final faces = await _detector.processImage(InputImage.fromFilePath(shot.path));
        unawaited(File(shot.path).delete().then((_) {}, onError: (_) {}));
        if (!mounted || _finished) break;
        _handle(faces);
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    _looping = false;
  }

  void _handle(List<Face> faces) {
    if (faces.isEmpty) {
      setState(() => _hint = 'No veo tu rostro. Acércate y busca buena luz.');
      return;
    }
    if (faces.length > 1) {
      setState(() => _hint = 'Solo debe haber una persona frente a la cámara.');
      return;
    }
    final f = faces.first;

    if (_stage == _Stage.face) {
      if (!FaceSignature.isFrontal(f)) {
        setState(() => _hint = 'Mira de frente y no inclines la cabeza');
        return;
      }
      if (!FaceSignature.isNeutral(f)) {
        setState(() => _hint = 'Mantén el rostro serio un momento');
        return;
      }
      final sig = FaceSignature.fromFace(f);
      if (sig == null) {
        setState(() => _hint = 'Acércate un poco más a la cámara');
        return;
      }

      if (_enroll) {
        _samples.add(sig);
        setState(() => _hint = 'Registrando… ${_samples.length}/$_samplesNeeded');
        if (_samples.length >= _samplesNeeded) {
          setState(() {
            _stage = _Stage.smile;
            _hint = '¡Ahora sonríe!';
          });
        }
      } else {
        final t = widget.template!;
        final d = FaceSignature.distance(sig, t.vector);
        final pct = FaceSignature.matchPercent(d, t.threshold);
        if (d <= t.threshold) {
          _goodMatches++;
        } else {
          _goodMatches = 0;
        }
        setState(() {
          _match = pct;
          _hint = d <= t.threshold ? 'Rostro reconocido… mantente así' : 'Buscando coincidencia…';
          if (_goodMatches >= 2) {
            _stage = _Stage.smile;
            _hint = '¡Ahora sonríe!';
          }
        });
      }
      return;
    }

    if (_stage == _Stage.smile && FaceSignature.isSmiling(f)) {
      if (_enroll) {
        final t = FaceSignature.buildTemplate(_samples);
        if (t == null) {
          _finish(false, 'No se pudo crear la plantilla facial. Intenta de nuevo.');
        } else {
          _finish(true, 'Rostro registrado correctamente', template: t);
        }
      } else {
        _finish(true, 'Rostro verificado correctamente');
      }
    }
  }

  void _finish(bool ok, String message, {FaceTemplate? template}) {
    if (_finished || !mounted) return;
    _finished = true;
    _looping = false;
    _deadline?.cancel();
    setState(() {
      _stage = ok ? _Stage.done : _stage;
      _hint = message;
    });
    Future<void>.delayed(Duration(milliseconds: ok ? 650 : 0), () {
      if (mounted) Navigator.of(context).pop(FaceScanResult(ok, message, template: template));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    const size = 270.0;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _finished = true;
        _looping = false;
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Palette.night),
          child: Stack(
            children: [
              const Positioned.fill(child: AnimeSparkles(count: 20, seed: 11)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(
                              const FaceScanResult(false, 'Verificación facial cancelada'),
                            ),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                          const Spacer(),
                          const MascotAvatar(size: 40),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _enroll ? 'Registro facial' : 'Verificación facial',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _enroll
                            ? 'Se guarda solo la forma de tu rostro, nunca la foto.'
                            : 'Paso 2: reconocimiento de rostro con la cámara frontal.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Palette.lilacSoft, fontSize: 13),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: size + 24,
                        height: size + 24,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: size + 24,
                              height: size + 24,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: _progress),
                                duration: const Duration(milliseconds: 350),
                                builder: (context, v, child) => CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 7,
                                  strokeCap: StrokeCap.round,
                                  color: _stage == _Stage.done ? const Color(0xFF7EE2B8) : Palette.lilac,
                                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            ClipOval(
                              child: SizedBox(
                                width: size,
                                height: size,
                                child: _error != null
                                    ? _CameraError(_error!)
                                    : (cam == null || !cam.value.isInitialized)
                                        ? const ColoredBox(
                                            color: Color(0x33FFFFFF),
                                            child: Center(child: CircularProgressIndicator(color: Palette.lilac)),
                                          )
                                        : FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: size,
                                              height: size * cam.value.aspectRatio,
                                              child: CameraPreview(cam),
                                            ),
                                          ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Chip(
                            icon: Icons.face_rounded,
                            label: _enroll ? 'Rostro' : 'Coincidencia',
                            done: _stage == _Stage.smile || _stage == _Stage.done,
                            active: _stage == _Stage.face,
                          ),
                          Container(width: 22, height: 2, color: Palette.lilac.withValues(alpha: 0.5)),
                          _Chip(
                            icon: Icons.sentiment_very_satisfied_rounded,
                            label: 'Sonrisa',
                            done: _stage == _Stage.done,
                            active: _stage == _Stage.smile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _hint,
                          key: ValueKey(_hint),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (_match != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Coincidencia: $_match%',
                          style: const TextStyle(color: Palette.lilac, fontWeight: FontWeight.w700),
                        ),
                      ],
                      const Spacer(),
                      const Text(
                        'Consejo: buena luz de frente, sin lentes oscuros ni cubrebocas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.lilacSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.done, required this.active});
  final IconData icon;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: done
            ? Palette.lilac
            : active
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: active ? Palette.lilac : Colors.transparent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_rounded : icon, size: 18, color: done ? Palette.plum : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: done ? Palette.plum : Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x33FFFFFF),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: Palette.lilac, size: 44),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
