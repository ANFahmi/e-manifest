import 'package:flutter/material.dart';
import 'package:emanifest/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emanifest/main_hall/home_page.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIdentity = prefs.getString('savedIdentity') ?? '';
    final savedPassword = prefs.getString('savedPassword') ?? '';

    setState(() {
      usernameController.text = savedIdentity;
      passwordController.text = savedPassword;
    });
  }

  void _login(BuildContext context) async {
    final identity = usernameController.text;
    final password = passwordController.text;

    final Map<String, String> roleToRoute = {
      'job_list': '/joblist',
      'cross_check_tmmin': '/kanbanTmmin',
      'cross_check_hmmi': '/kanbanHmmi',
      'cross_check_adm': '/kanbanAdm',
    };

    final url = Uri.parse('https://mspin.newarmada.biz/sto/auth/login-app');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode({
      'identity': identity,
      'password': password,
      'remember': false,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          final success = await AuthService().login('it.tbn', '@4Rm4d4107');

          if (success) {
            final token = data['token'];
            final payload = JwtDecoder.decode(token);
            final List<String> accessPayload = List<String>.from(payload['payload'] ?? []);

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('savedIdentity', identity);
            await prefs.setString('savedPassword', password);

            // bool navigated = false;
            // for (final role in accessPayload) {
            //   if (roleToRoute.containsKey(role)) {
            //     Navigator.pushReplacementNamed(context, roleToRoute[role]!);
            //     navigated = true;
            //     break;
            //   }
            // }

            // if (!navigated) {
            //   _showErrorDialog(context, 'Tidak ada akses yang sesuai.');
            // }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage()),
            );
          } else {
            _showErrorDialog(context, 'Login ke API Toyota gagal.');
          }
        } else {
          _showErrorDialog(context, data['message'] ?? 'Login gagal.');
        }
      } else {
        _showErrorDialog(context, 'Login gagal dengan status ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog(context, 'Terjadi kesalahan saat login: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Gagal'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Tutup'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/img/MAJ-LOGO-3.png',
                  height: 100,
                ),

                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'E-MANIFEST LOGIN',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Masukkan Username Anda',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.person, color: Colors.grey[600]),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                            ),
                            validator: (value) => value!.isEmpty ? 'Harap masukkan username' : null,
                          ),
                          const SizedBox(height: 16),
                          // TextFormField Password
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              hintText: 'Masukkan Password Anda',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.lock, color: Colors.grey[600]),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 1.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              errorStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                            ),
                            validator: (value) => value!.isEmpty ? 'Harap masukkan password' : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _login(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '© IT Department PT Mekar Armada Jaya',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
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

