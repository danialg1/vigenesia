import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:another_flushbar/flushbar.dart';

import '../Constant/const.dart';

class CreatePostScreen extends StatefulWidget {
  final String iduser;
  final String? repostId;
  final Map<String, dynamic>? originalPostData;

  const CreatePostScreen({Key? key, required this.iduser, this.repostId, this.originalPostData}) : super(key: key);

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _isiController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  Future<void> _submitPost() async {
    String text = _isiController.text.trim();
    if (text.isEmpty && _selectedImage == null && widget.repostId == null) {
      if (mounted) {
        Flushbar(
          message: "Postingan tidak boleh kosong",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ).show(context);
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> dataMap = {
        "isi_motivasi": text,
        "iduser": widget.iduser,
      };
      if (widget.repostId != null) {
        dataMap["repost_id"] = widget.repostId;
      }
      FormData formData = FormData.fromMap(dataMap);

      if (_selectedImage != null) {
        formData.files.add(MapEntry(
          "foto",
          await MultipartFile.fromFile(_selectedImage!.path,
              filename: _selectedImage!.path.split('/').last),
        ));
      }

      var response = await dio.post(
        '$url/motivasi_post.php',
        data: formData,
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        if (mounted) {
          Flushbar(
            message: "Gagal memposting",
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ).show(context);
        }
      }
    } catch (e) {
      debugPrint("Post error: $e");
      if (mounted) {
        Flushbar(
          message: "Terjadi kesalahan koneksi",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ).show(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Posting", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _isiController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: "Apa yang sedang terjadi?",
                              hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, left: 52),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImage = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.repostId != null && widget.originalPostData != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16, left: 52),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.originalPostData!['nama_user'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(widget.originalPostData!['isi_motivasi'] ?? ''),
                              if (widget.originalPostData!['foto_motivasi'] != null && widget.originalPostData!['foto_motivasi'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      '$url/uploads/${widget.originalPostData!['foto_motivasi']}',
                                      width: double.infinity,
                                      fit: BoxFit.cover,
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
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image, color: Colors.blue),
                    onPressed: _pickImage,
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
