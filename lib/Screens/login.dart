import 'dart:convert';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main_screens.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'package:flutter/gestures.dart';
import '../Models/login_model.dart';
import '../Constant/const.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  String? nama;
  bool _obscurePassword = true;

  final GlobalKey<FormBuilderState> _fbKey = GlobalKey<FormBuilderState>();

  Future<LoginModels?> postLogin(String email, String password) async {
    var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));

    // Send as JSON data
    Map<String, dynamic> data = {"email": email, "password": password};

    try {
      final response = await dio.post(
        "$url/login.php",
        data: jsonEncode(data), // IMPORTANT: Encode as JSON string
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      debugPrint("Response -> ${response.data} + ${response.statusCode}");

      if (response.statusCode == 200) {
        // Check if response is valid JSON
        if (response.data is Map || response.data is List) {
          final loginModel = LoginModels.fromJson(response.data);
          return loginModel;
        } else {
          debugPrint("Invalid response format: ${response.data}");
          return null;
        }
      }
    } on DioException catch (e) {
      debugPrint("DioException: $e");
      debugPrint("Error Type: ${e.type}");
      debugPrint("Error Message: ${e.message}");

      if (e.response != null) {
        debugPrint("Response Data: ${e.response?.data}");
        debugPrint("Response Status: ${e.response?.statusCode}");
      }

      // Show error to user
      if (mounted) {
        String errorMessage = "Connection error";
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = "Connection timeout. Check your internet.";
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = "Server not responding";
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = "Cannot connect to server. Check URL configuration.";
        }
        Flushbar(
          message: errorMessage,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.redAccent,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
    return null;
  }

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.blueGrey.shade900, Colors.black, Colors.black]
                : [
                    const Color(0xFF4FC3F7), // Light blue
                    const Color(0xFF1976D2), // Primary blue
                    const Color(0xFF0D47A1), // Dark blue
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // App Icon / Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Vigenesia",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Login Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _fbKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Sign In",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.blue.shade300 : const Color(0xFF1976D2),
                            ),
                          ),
                          const SizedBox(height: 30),
                          // Email Field
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : const Color(0xFFF5F9FC),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: "Email",
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF1976D2),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Password Field with visibility toggle
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : const Color(0xFFF5F9FC),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: "Password",
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF1976D2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFF1976D2),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          // Sign In Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF42A5F5),
                                  Color(0xFF1976D2),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1976D2).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                // Validate inputs
                                if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                                  Flushbar(
                                    message: "Please fill all fields",
                                    duration: const Duration(seconds: 3),
                                    backgroundColor: Colors.orange,
                                    flushbarPosition: FlushbarPosition.TOP,
                                  ).show(context);
                                  return;
                                }

                                var value = await postLogin(
                                    emailController.text, passwordController.text);
                                if (!mounted) return;
                                if (value != null && value.isActive == true && value.data != null) {
                                  setState(() {
                                    nama = value.data?.nama;
                                  });
                                  // Simpan data ke SharedPreferences
                                  SharedPreferences prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('iduser', value.data?.id ?? '');
                                  await prefs.setString('nama', value.data?.nama ?? '');
                                  await prefs.setString('profesi', value.data?.profesi ?? '');
                                  await prefs.setString('email', value.data?.email ?? '');
                                  await prefs.setString('roleId', value.data?.roleId ?? '');
                                  await prefs.setString('foto', value.data?.foto ?? '');
                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                MainScreens(nama: nama!, iduser: value.data?.id, roleId: value.data?.roleId)));
                                  }
                                } else {
                                  if (context.mounted) {
                                    Flushbar(
                                      message: "Invalid email or password",
                                      duration: const Duration(seconds: 5),
                                      backgroundColor: Colors.redAccent,
                                      flushbarPosition: FlushbarPosition.TOP,
                                    ).show(context);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                "Sign In",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Forgot Password Link
                          Text.rich(
                            TextSpan(
                              text: "Forgot your password? ",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Reset Here',
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const ForgotPassword()));
                                    },
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Sign Up Link
                          Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign Up',
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => const Register()));
                                    },
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
