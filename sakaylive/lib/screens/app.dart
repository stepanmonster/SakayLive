// lib/app.dart - FIXED ✅
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/map_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import 'package:sakaylive/screens/map_screen.dart'; // Your MapScreen with auth gating

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()), // ✅ Auth gating
      ],
      child: MaterialApp(
        title: 'SakayLive',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Poppins'),
        home: const MapScreen(), // MapScreen NOW has AuthViewModel access
      ),
    );
  }
}
