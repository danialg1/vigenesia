import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Constant/const.dart';

class UserRepository {
  final Dio _dio;

  UserRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));

  Future<Map<String, dynamic>> updateProfile({
    required String idUser,
    required String nama,
    required String profesi,
    File? foto,
  }) async {
    try {
      var formDataMap = {
        'iduser': idUser,
        'nama': nama,
        'profesi': profesi,
      };

      var formData = FormData.fromMap(formDataMap);

      if (foto != null) {
        formData.files.add(
          MapEntry(
            'foto',
            await MultipartFile.fromFile(
              foto.path,
              filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
            ),
          ),
        );
      }

      var response = await _dio.post(
        '$url/user_update.php',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        bool isSuccess = false;
        String msg = 'Profile berhasil diupdate';
        
        if (response.data is Map<String, dynamic>) {
          isSuccess = response.data['success'] == true;
          msg = response.data['message'] ?? msg;
          
          if (isSuccess) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('nama', nama);
            await prefs.setString('profesi', profesi);

            if (response.data['foto_baru'] != null) {
              await prefs.setString('foto', response.data['foto_baru'].toString());
            }
          }
        }
        
        return {
          'success': isSuccess,
          'message': msg
        };
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Gagal update profile'
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Terjadi kesalahan';
      if (e.response != null) {
        errorMessage = e.response?.data?['message'] ?? errorMessage;
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Koneksi timeout';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Tidak ada koneksi internet';
      }
      return {
        'success': false,
        'message': errorMessage
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e'
      };
    }
  }

  Future<Map<String, String>> getCurrentProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'iduser': prefs.getString('iduser') ?? '',
      'nama': prefs.getString('nama') ?? '',
      'profesi': prefs.getString('profesi') ?? '',
      'foto': prefs.getString('foto') ?? '',
    };
  }
}
