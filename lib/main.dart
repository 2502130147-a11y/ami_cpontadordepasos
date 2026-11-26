import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/amatista_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF7F2FC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AmatistaApp());
}
