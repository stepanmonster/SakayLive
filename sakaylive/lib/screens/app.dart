// lib/app.dart - FULL ROUTING FIXED ✅
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakaylive/screens/admin/admin_page.dart';
import '../viewmodels/map_view_model.dart';
import '../viewmodels/auth_view_model.dart';
import 'package:sakaylive/screens/map_screen.dart';
import 'package:sakaylive/screens/login_page.dart';    // ← ADD YOUR LOGIN SCREEN
import 'package:sakaylive/screens/conductor/conductor_dashboard.dart'; // ← IF EXISTS
import 'package:sakaylive/screens/account_page.dart';
import 'landing_page1.dart';   

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
        
        home: const AuthWrapper(),  // Role-based entry
        initialRoute: null,
        
        // ALL existing routes preserved ✅
        routes: {
          '/landing': (context) => const LandingPage1(),
          '/map': (context) => const MapScreen(),
          '/login': (context) => const LoginPage(),
          '/conductor': (context) => const ConductorDashboard(),  // FAB/Drawer target
          '/profile': (context) => const AccountPage(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        if (authViewModel.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (!authViewModel.isLoggedIn) {
          return const LandingPage1();
        }

        // ✅ NEW PRIORITY: Admin > Conductor/Commuter both → MapScreen
        if (authViewModel.isAdmin!) {
          return const AdminPage(); // Replace: AdminPanelScreen()
        } 
        
        // ✅ BOTH conductors + commuters → MapScreen (FAB shows conductor features)
        return const MapScreen();
      },
    );
  }
}


