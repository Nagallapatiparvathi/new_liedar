import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'splash_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  Future<bool> _isUsernameTaken(String username) async {
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('username', username)
            .maybeSingle();
    return res != null;
  }

  Future<bool> _doesProfileExist(String id) async {
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('id', id)
            .maybeSingle();
    return res != null;
  }

  Future<String> _generateUniqueUsername(String email) async {
    String baseUsername = email.split('@')[0];
    String username = baseUsername;
    int attempt = 0;
    while (await _isUsernameTaken(username)) {
      attempt++;
      username = "$baseUsername$attempt";
    }
    return username;
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter email and password.")));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Login failed. Please check credentials or confirm your email.",
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // If profile does not exist, create with unique username
      if (!await _doesProfileExist(user.id)) {
        final username = await _generateUniqueUsername(email);
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': username,
        });
      }

      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SplashScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login failed: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signup() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Enter email and password.")));
      setState(() => _isLoading = false);
      return;
    }

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Signup successful! Please check your email you will get mail from SUPABASE BY CLICKING IT YOU WILL FIND CONFIRM YOUR MAIL LINK ,CLICK that link to confirm your account, then log in.",
          ),
        ),
      );
      setState(() => _isLoading = false);
      setState(() => _isLogin = true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Signup failed: $e")));
      setState(() => _isLoading = false);
    }
  }

  Widget _authForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              decoration: InputDecoration(labelText: "Email"),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : () {
                        if (_isLogin) {
                          _login();
                        } else {
                          _signup();
                        }
                      },
              child:
                  _isLoading
                      ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(_isLogin ? "Login" : "Sign Up"),
            ),
            SizedBox(height: 12),
            TextButton(
              child: Text(
                _isLogin
                    ? "Don't have an account? Sign Up"
                    : "Already have an account? Login",
              ),
              onPressed: () {
                setState(() => _isLogin = !_isLogin);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? "Login" : "Sign Up")),
      body: Center(child: _authForm()),
    );
  }
}
