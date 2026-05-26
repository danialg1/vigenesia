import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../Models/Motivasi_Model.dart';
import '../Screens/EditPage.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'Login.dart';
import 'package:another_flushbar/flushbar.dart';
import '../Constant/const.dart';

class MainScreens extends StatefulWidget {
  final String? nama;
  final String? iduser;
  final String? roleId;
  const MainScreens({Key? key, this.nama, this.iduser, this.roleId}) : super(key: key);

  @override
  _MainScreensState createState() => _MainScreensState();
}

class _MainScreensState extends State<MainScreens> {
  String? id;
  var dio = Dio();
  Set<String> likedPosts = {};
  Set<String> savedPosts = {};
  Map<String, int> likeCounts = {};

  Future<dynamic> sendMotivasi(String isi) async {
    Map<String, dynamic> body = {
      "isi_motivasi": isi,
      "iduser": widget.iduser,
    };

    try {
      Response response = await dio.post("$url/motivasi_post.php", data: body);
      print("Respon -> ${response.data} + ${response.statusCode}");
      return response;
    } catch (e) {
      print("Error di -> $e");
    }
  }

  Future<List<MotivasiModel>> getData() async {
    var response = await dio.get('$url/motivasi_get.php');
    print(" ${response.data}");
    if (response.statusCode == 200) {
      var motivasiList = (response.data['data']['motivasi'] ?? []) as List;
      var listUsers = motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
      for (var item in listUsers) {
        likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
      }
      return listUsers;
    } else {
      throw Exception('Failed to load');
    }
  }

  Future<dynamic> deletePost(String id) async {
    dynamic data = {"id": id};
    var response = await dio.delete('$url/motivasi_delete.php',
        data: data,
        options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {"Content-type": "application/json"}));
    print(" ${response.data}");
    return response.data;
  }

  Future<void> _getData() async {
    setState(() {
      getData();
    });
  }

  void _toggleLike(String? postId) async {
    if (postId == null) return;
    try {
      var response = await dio.post('$url/like_action.php', data: {
        "id_motivasi": postId,
        "iduser": widget.iduser ?? "",
      });
      var action = response.data['action'];
      setState(() {
        if (action == 'liked') {
          likedPosts.add(postId);
        } else {
          likedPosts.remove(postId);
        }
        likeCounts[postId] = response.data['total_likes'] ?? 0;
      });
    } catch (e) {
      print("Like error: $e");
    }
  }

  void _toggleSave(String? postId) {
    setState(() {
      if (savedPosts.contains(postId)) {
        savedPosts.remove(postId);
      } else {
        savedPosts.add(postId!);
      }
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  void _showCommentSheet(BuildContext context, String? idMotivasi, String? postOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (builderContext, setSheetState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Komentar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: FutureBuilder(
                      future: dio.get('$url/comment_get.php?id_motivasi=${idMotivasi ?? ""}'),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        var comments = snapshot.data?.data?['data'] ?? [];
                        if (comments.isEmpty) {
                          return const Center(child: Text('Belum ada komentar'));
                        }
                        return ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, index) {
                            var comment = comments[index] as Map<String, dynamic>? ?? {};
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  (comment['nama_user']?.toString() ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(comment['nama_user']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(comment['isi_komentar']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                              trailing: Text(_formatDate(DateTime.tryParse(comment['tanggal_input']?.toString() ?? '')),
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: "Tulis komentar...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: () async {
                          if (commentController.text.isEmpty) return;
                          try {
                            await dio.post('$url/comment_post.php', data: {
                              "id_motivasi": idMotivasi ?? "",
                              "iduser": widget.iduser ?? "",
                              "isi_komentar": commentController.text,
                            });
                            commentController.clear();
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                            _showCommentSheet(context, idMotivasi, postOwnerId);
                          } catch (e) {
                            if (builderContext.mounted) {
                              Flushbar(
                                message: "Gagal mengirim komentar",
                                duration: const Duration(seconds: 2),
                                backgroundColor: Colors.red,
                                flushbarPosition: FlushbarPosition.TOP,
                              ).show(builderContext);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  TextEditingController isiController = TextEditingController();
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getData();
    _getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _getData,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Hallo  ${widget.nama}",
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                          Text(widget.roleId == '1' ? ' [Admin]' : ' [Member]',
                              style: TextStyle(
                                color: widget.roleId == '1' ? Colors.red : Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              )),
                        ],
                      ),
                      TextButton(
                        child: const Icon(Icons.logout),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => Login()));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: const Icon(Icons.person, color: Colors.blue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FormBuilderTextField(
                                  controller: isiController,
                                  name: "isi_motivasi",
                                  decoration: InputDecoration(
                                    hintText: "Apa yang kamu pikirkan?",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  if (isiController.text.isEmpty) {
                                    Flushbar(
                                      message: "Kolom motivasi tidak boleh kosong",
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.orange,
                                      flushbarPosition: FlushbarPosition.TOP,
                                    ).show(context);
                                    return;
                                  }
                                  await sendMotivasi(isiController.text.toString()).then((value) {
                                    if (value != null) {
                                      isiController.clear();
                                      Flushbar(
                                        message: "Berhasil Posting!",
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: Colors.green,
                                        flushbarPosition: FlushbarPosition.TOP,
                                      ).show(context);
                                    }
                                  });
                                  _getData();
                                },
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text("Posting"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder(
                    future: getData(),
                    builder: (context, AsyncSnapshot<List<MotivasiModel>> snapshot) {
                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator());
                      }
                      if (snapshot.data!.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(50),
                          child: Column(
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text("Belum ada motivasi", style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          var item = snapshot.data![index];
                          bool isLiked = likedPosts.contains(item.id);
                          bool isSaved = savedPosts.contains(item.id);
                          bool isOwner = item.iduser == widget.iduser;
                          bool isAdmin = widget.roleId == '1';
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          (item.namaUser ?? 'U')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.namaUser ?? 'User',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            Text(_formatDate(item.tanggalInput),
                                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(item.isiMotivasi ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
                                  const SizedBox(height: 16),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _toggleLike(item.id),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                                                    color: isLiked ? Colors.red : Colors.grey, size: 22),
                                                const SizedBox(width: 4),
                                                Text(isLiked ? 'Liked (${likeCounts[item.id] ?? 0})' : 'Like (${likeCounts[item.id] ?? 0})',
                                                    style: TextStyle(color: isLiked ? Colors.red : Colors.grey, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        InkWell(
                                          onTap: () => _toggleSave(item.id),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? Colors.orange : Colors.grey, size: 22),
                                                const SizedBox(width: 4),
                                                Text(isSaved ? 'Saved' : 'Save', style: TextStyle(color: isSaved ? Colors.orange : Colors.grey, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        InkWell(
                                          onTap: () => _showCommentSheet(context, item.id, item.iduser),
                                          borderRadius: BorderRadius.circular(20),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 22),
                                                SizedBox(width: 4),
                                                Text('Comment', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        InkWell(
                                          onTap: () {
                                            SharePlus.instance.share(ShareParams(text: 'Cek motivasi keren ini di Vigenesia: "${item.isiMotivasi}" - dari ${item.namaUser}'));
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(Icons.share, color: Colors.grey, size: 22),
                                                SizedBox(width: 4),
                                                Text('Share', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        if (isOwner || isAdmin) ...[
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            onPressed: () {
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (context) => EditPage(id: item.id, isi_motivasi: item.isiMotivasi),
                                              )).then((_) => _getData());
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text("Hapus Motivasi"),
                                                  content: const Text("Apakah kamu yakin ingin menghapus motivasi ini?"),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      child: const Text("Batal"),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        deletePost(item.id!).then((value) {
                                                          if (value != null) {
                                                            Flushbar(
                                                              message: "Berhasil Dihapus",
                                                              duration: const Duration(seconds: 2),
                                                              backgroundColor: Colors.green,
                                                              flushbarPosition: FlushbarPosition.TOP,
                                                            ).show(context);
                                                          }
                                                        });
                                                        _getData();
                                                      },
                                                      child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}