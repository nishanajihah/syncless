import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../workspace/presentation/workspace_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingView();
        }

        return snapshot.data?.session == null
            ? const _SignInPage()
            : const WorkspacePage();
      },
    );
  }
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _statusMessage = 'Enter a valid email address to continue.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Checking account status...';
    });

    bool userExists = false;
    try {
      final check = await Supabase.instance.client.rpc(
        'check_user_exists',
        params: {'p_email': email},
      );
      userExists = check == true;
    } catch (_) {
      // Fallback if RPC is not yet deployed
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = userExists
          ? 'Existing account found. Sending login link...'
          : 'New email detected. Creating your Syncless account...';
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = userExists
            ? 'Account found! We sent a magic link to log you in.'
            : 'Welcome to Syncless! We sent a magic link to activate your new account.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Authentication failed: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Unexpected error occurred: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B0F),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF101116),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF262833)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9CA8FF), Color(0xFF6D5DF5)],
                        ),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white),
                    ),
                    const SizedBox(height: 28),
                     const Text(
                      'Welcome to Syncless',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Turn conversations into execution-ready work. Enter your email to instantly log in or register.',
                      style: TextStyle(color: Color(0xFF9398AA), fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _isSubmitting ? null : _sendMagicLink(),
                      decoration: const InputDecoration(
                        labelText: 'Email to Sign Up / Log In',
                        hintText: 'you@domain.com',
                        filled: true,
                        fillColor: Color(0xFF161820),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _statusMessage!,
                        style: const TextStyle(color: Color(0xFFB9C5FF), fontSize: 15),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _sendMagicLink,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C6CFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Continue with email'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'By continuing, you agree to receive a one-time sign-in link.',
                      style: TextStyle(color: Color(0xFF73788B), fontSize: 14, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLoadingView extends StatelessWidget {
  const _AuthLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0B0F),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _statusMessage = 'Enter a valid email address to continue.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Checking account status...';
    });

    bool userExists = false;
    try {
      final check = await Supabase.instance.client.rpc(
        'check_user_exists',
        params: {'p_email': email},
      );
      userExists = check == true;
    } catch (_) {
      // Fallback if RPC is not yet deployed
    }

    if (!mounted) return;
    setState(() {
      _statusMessage = userExists
          ? 'Existing account found. Sending login link...'
          : 'New email detected. Creating your Syncless account...';
    });

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      if (!mounted) return;
      setState(() {
        _statusMessage = userExists
            ? 'Account found! We sent a magic link to log you in.'
            : 'Welcome to Syncless! We sent a magic link to activate your new account.';
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Authentication failed: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Unexpected error occurred: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF101116),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF262833)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9CA8FF), Color(0xFF6D5DF5)],
                        ),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF73788B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to Syncless',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email to instantly log in or register. A secure magic link will be sent to your inbox.',
                  style: TextStyle(color: Color(0xFF9398AA), fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _isSubmitting ? null : _sendMagicLink(),
                  decoration: const InputDecoration(
                    labelText: 'Email to Sign Up / Log In',
                    hintText: 'you@domain.com',
                    filled: true,
                    fillColor: Color(0xFF161820),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(color: Color(0xFFB9C5FF), fontSize: 15),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _sendMagicLink,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C6CFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue with email'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
