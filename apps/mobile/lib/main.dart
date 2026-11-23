import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PjtApp());
}

class PjtApp extends StatelessWidget {
  const PjtApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PJT',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const HomeScreen(),
  );
}
