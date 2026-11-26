import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/logic/auth_store.dart';
import 'tracking_page.dart';

/// Abre una sesión nueva con la zancada y el peso del perfil.
void openTracking(BuildContext context) {
  final acc = context.read<AuthStore>().account;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TrackingPage(
        strideM: acc?.strideM ?? 0.70,
        weightKg: acc?.weightKg ?? 65,
      ),
    ),
  );
}
