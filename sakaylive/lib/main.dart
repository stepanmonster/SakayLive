// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import './screens/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // UI overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Environment + Mapbox
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.get('MAPBOX_ACCESS_TOKEN', fallback: ''));

  runApp(const App());
}
