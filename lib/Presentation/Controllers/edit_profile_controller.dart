import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../Data/Repositories/user_repository.dart';

class EditProfileController extends ChangeNotifier {
  final UserRepository _repository;

  EditProfileController({UserRepository? repository}) 
      : _repository = repository ?? UserRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPickerActive = false;

  String? _iduser;
  String? _currentImageUrl;
  String? get currentImageUrl => _currentImageUrl;

  File? _selectedImage;
  File? get selectedImage => _selectedImage;

  final TextEditingController namaController = TextEditingController();
  final TextEditingController profesiController = TextEditingController();

  Future<void> loadCurrentProfile() async {
    final profile = await _repository.getCurrentProfile();
    _iduser = profile['iduser'];
    namaController.text = profile['nama'] ?? '';
    profesiController.text = profile['profesi'] ?? '';
    _currentImageUrl = profile['foto'];
    notifyListeners();
  }

  Future<void> pickImage() async {
    // LOCK MECHANISM to prevent PlatformException(already_active)
    if (_isPickerActive) return;
    
    _isPickerActive = true;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        _selectedImage = File(image.path);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Image Picker Error: \$e");
    } finally {
      _isPickerActive = false;
    }
  }

  Future<Map<String, dynamic>> submitProfile() async {
    if (_iduser == null || _iduser!.isEmpty) {
      return {'success': false, 'message': 'ID User tidak ditemukan'};
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repository.updateProfile(
        idUser: _iduser!,
        nama: namaController.text.trim(),
        profesi: profesiController.text.trim(),
        foto: _selectedImage,
      );
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    profesiController.dispose();
    super.dispose();
  }
}
