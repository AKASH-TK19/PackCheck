import 'package:flutter/material.dart';

import '../models/officer_session.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class OfficerLoginScreen extends StatefulWidget {
  const OfficerLoginScreen({super.key});

  @override
  State<OfficerLoginScreen> createState() => _OfficerLoginScreenState();
}

class _OfficerLoginScreenState extends State<OfficerLoginScreen> {
  final officerIdController = TextEditingController(
      text: OfficerSession.officerId ?? '',
    );
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool loggingIn = false;

  @override
  void dispose() {
    officerIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final id = officerIdController.text.trim();
    final password = passwordController.text;

    if (id.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Officer ID and password.')),
      );
      return;
    }

    setState(() => loggingIn = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    // Hackathon demo credentials only. Production deployment should use
    // departmental authentication / SSO and never hard-code credentials.
    final creds = <String, String>{
      'LM001': 'OFFICER',
      'ADM001': 'ADMIN',
    };

    final role = creds[id] == null
        ? null
        : (password == 'LM@1234' ? creds[id] : null);

    final valid = role != null;

    if (!mounted) return;

    if (!valid) {
      setState(() => loggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid officer credentials.')),
      );
      return;
    }

    OfficerSession.officerId = id;
    OfficerSession.role = role;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const PackCheckLogo(size: 84),
                  const SizedBox(height: 22),
                  const Text(
                    'PACKCHECK',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: PackCheckColors.dark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI-Powered Package Compliance Scanner',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Officer Sign In',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: officerIdController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Officer ID',
                            hintText: 'Enter Officer ID',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          onSubmitted: (_) => login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => obscurePassword = !obscurePassword);
                              },
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: loggingIn ? null : login,
                            icon: loggingIn
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              loggingIn ? 'AUTHENTICATING...' : 'SIGN IN',
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Authorised personnel only',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hackathon prototype authentication',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
