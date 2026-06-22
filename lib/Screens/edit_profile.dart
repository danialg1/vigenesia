import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import '../Constant/const.dart';
import '../Presentation/Controllers/edit_profile_controller.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({Key? key}) : super(key: key);

  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final EditProfileController _controller = EditProfileController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller.loadCurrentProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final result = await _controller.submitProfile();
    
    if (!mounted) return;

    if (result['success']) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      if (!mounted) return;
      Flushbar(
        message: result['message'] ?? 'Gagal',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Header dengan gradient
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Column(
                    children: [
                      // Avatar dengan pilihan foto
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _controller.isLoading ? null : _controller.pickImage,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: _buildAvatar(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1976D2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap foto untuk mengubah',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Form
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Nama Field
                              TextFormField(
                                controller: _controller.namaController,
                                enabled: !_controller.isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Nama',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Nama tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Profesi Field
                              TextFormField(
                                controller: _controller.profesiController,
                                enabled: !_controller.isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Profesi',
                                  prefixIcon: const Icon(Icons.work_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Profesi tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              // Submit Button
                              ElevatedButton(
                                onPressed: _controller.isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1976D2),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _controller.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Simpan Perubahan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              // Cancel Button
                              TextButton(
                                onPressed: _controller.isLoading ? null : () => Navigator.pop(context),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar() {
    if (_controller.selectedImage != null) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[200],
        backgroundImage: FileImage(_controller.selectedImage!),
      );
    } else if (_controller.currentImageUrl != null && _controller.currentImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage('$url/uploads/${_controller.currentImageUrl}'),
      );
    } else {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[200],
        child: const Icon(Icons.person, size: 60, color: Colors.grey),
      );
    }
  }
}
