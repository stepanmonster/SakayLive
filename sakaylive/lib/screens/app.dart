// lib/app.dart
import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'map_screen.dart'; // Use this if no auth needed

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SakayLive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Poppins'),
      home: MapScreen(), // or MapScreen()
    );
  }
}
