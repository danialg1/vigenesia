import '../Constant/const.dart';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:dio/dio.dart';

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  bool _obscurePassword = true;

  Future<Map<String, dynamic>?> postRegister(
      String nama, String profesi, String email, String password) async {
    var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));

    try {
      final response = await dio.post(
        "$url/user_post.php",
        data: {
          "nama": nama,
          "profesi": profesi,
          "email": email,
          "password": password,
          "role_id": "2"
        },
        options: Options(
          headers: {'Content-type': 'application/json'},
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint("Respon -> ${response.data} + ${response.statusCode}");

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": response.data,
          "message": response.data['message'] ?? 'Berhasil Registrasi'
        };
      } else {
        return {
          "success": false,
          "message": response.data['message'] ?? 'Terjadi kesalahan'
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Gagal terhubung ke server';

      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Koneksi timeout';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Tidak ada koneksi internet';
      } else if (e.response != null) {
        // Ambil pesan error dari server jika ada
        errorMessage = e.response?.data?['message'] ??
                       e.response?.statusMessage ??
                       'Error ${e.response?.statusCode}';
      }

      return {
        "success": false,
        "message": errorMessage,
        "isNetworkError": e.type == DioExceptionType.connectionError
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Error: ${e.toString()}"
      };
    }
  }

  TextEditingController nameController = TextEditingController();
  TextEditingController profesiController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 1.3,
              height: MediaQuery.of(context).size.height,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Register Your Account",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 50),
                  FormBuilderTextField(
                    name: "name",
                    controller: nameController,
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                        border: OutlineInputBorder(),
                        labelText: "Nama"),
                  ),
                  const SizedBox(height: 20),
                  FormBuilderTextField(
                    name: "profesi",
                    controller: profesiController,
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                        border: OutlineInputBorder(),
                        labelText: "Profesi"),
                  ),
                  const SizedBox(height: 20),
                  FormBuilderTextField(
                    name: "email",
                    controller: emailController,
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10),
                        border: OutlineInputBorder(),
                        labelText: "Email"),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  StatefulBuilder(
                    builder: (context, setState) {
                      return FormBuilderTextField(
                        obscureText: _obscurePassword,
                        name: "password",
                        controller: passwordController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.only(left: 10, right: 10),
                          border: const OutlineInputBorder(),
                          labelText: "Password",
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
                        ),
                      );
                    },
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              profesiController.text.isEmpty ||
                              emailController.text.isEmpty ||
                              passwordController.text.isEmpty) {
                            Flushbar(
                              message: "Semua field harus diisi!",
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.orange,
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(context);
                            return;
                          }

                          var result = await postRegister(
                            nameController.text,
                            profesiController.text,
                            emailController.text,
                            passwordController.text,
                          );

                          if (result != null && result["success"] == true) {
                            setState(() {});
                            Flushbar(
                              message: result["message"] ?? "Berhasil Registrasi",
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(context);
                            await Future.delayed(const Duration(seconds: 2));
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          } else {
                            Flushbar(
                              message: result?["message"] ?? "Gagal registrasi",
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.red,
                              flushbarPosition: FlushbarPosition.TOP,
                            ).show(context);
                          }
                        },
                        child: const Text("Daftar")),
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
