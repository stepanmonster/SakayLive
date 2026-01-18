// lib/app.dart - FULL ROUTING FIXED ✅
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/map_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import 'package:sakaylive/screens/map_screen.dart';
import 'package:sakaylive/screens/landing_page3.dart';  // ← ADD YOUR LANDING SCREEN
import 'package:sakaylive/screens/login_page.dart';    // ← ADD YOUR LOGIN SCREEN
import 'package:sakaylive/screens/conductor/conductor_dashboard.dart'; // ← IF EXISTS

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapViewModel()),
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ],
      child: MaterialApp(
        title: 'SakayLive',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Poppins'),
        
        initialRoute: '/landing',  // Start here
        routes: {
          '/landing': (context) => const LandingPage3(),
          '/map': (context) => const MapScreen(),
          '/login': (context) => const LoginPage(),
          '/conductor': (context) => const ConductorDashboard(),
        },
      ),
    );
  }
}

