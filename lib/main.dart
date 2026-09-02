import 'package:flutter/material.dart';

import 'screens/officer_login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const LMInspectApp());
}

class LMInspectApp extends StatelessWidget {
  const LMInspectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PackCheck',
      theme: buildPackCheckTheme(),
      home: const OfficerLoginScreen(),
    );
  }
}
