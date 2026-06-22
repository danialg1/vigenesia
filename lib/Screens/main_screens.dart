import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/motivasi_model.dart';
import '../Screens/edit_page.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'login.dart';
import 'follow.dart';
import 'notification_page.dart';
import 'profile.dart';
import 'package:another_flushbar/flushbar.dart';
import '../Constant/const.dart';
class MainScreens extends StatefulWidget {
  final String? nama;
  final String? iduser;
  final String? roleId;
  const MainScreens({Key? key, this.nama, this.iduser, this.roleId})
      : super(key: key);

  @override
  _MainScreensState createState() => _MainScreensState();
}

class _MainScreensState extends State<MainScreens> {
  int _selectedIndex = 0;
  String? id;
  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));
  Set<String> likedPosts = {};
  Set<String> savedPosts = {};
  Map<String, int> likeCounts = {};

  // EPIC 1: Current user photo from SharedPreferences
  String? currentUserFoto;

  Future<dynamic> sendMotivasi(String isi) async {
    Map<String, dynamic> body = {
      "isi_motivasi": isi,
      "iduser": widget.iduser,
    };

    try {
      Response response = await dio.post("$url/motivasi_post.php", data: body);
      debugPrint("Respon -> ${response.data} + ${response.statusCode}");
      return response;
    } catch (e) {
      debugPrint("Error di -> $e");
    }
  }

  Stream<List<MotivasiModel>> getPostsStream() async* {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_main_posts');
    if (cachedData != null) {
      try {
        var jsonData = json.decode(cachedData);
        var motivasiList = (jsonData['data'] ?? []) as List;
        var listUsers = motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
        for (var item in listUsers) {
          likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
          if (item.isLiked == true || (item.userReaction != null && item.userReaction!.isNotEmpty)) {
            likedPosts.add(item.id ?? '');
          }
        }
        yield listUsers;
      } catch (e) {
        debugPrint("Cache error: $e");
      }
    }

    try {
      var response = await dio.get('$url/motivasi_get.php?iduser=${widget.iduser ?? ""}&current_user_id=${widget.iduser ?? ""}');
      debugPrint(" ${response.data}");
      if (response.statusCode == 200) {
        prefs.setString('cached_main_posts', json.encode(response.data));
        var motivasiList = (response.data['data'] ?? []) as List;
        var listUsers = motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
        for (var item in listUsers) {
          likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
          if (item.isLiked == true || (item.userReaction != null && item.userReaction!.isNotEmpty)) {
            likedPosts.add(item.id ?? '');
          }
        }
        yield listUsers;
      } else {
        throw Exception('Failed to load');
      }
    } catch (e) {
      debugPrint("Error: $e");
      throw Exception('Failed to load');
    }
  }

  Future<List<MotivasiModel>> getData() async {
    // Keep getData for backwards compatibility where it's explicitly awaited
    var response =
        await dio.get('$url/motivasi_get.php?iduser=${widget.iduser ?? ""}&current_user_id=${widget.iduser ?? ""}');
    if (response.statusCode == 200) {
      var motivasiList = (response.data['data'] ?? []) as List;
      var listUsers =
          motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
      for (var item in listUsers) {
        likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
        if (item.isLiked == true || (item.userReaction != null && item.userReaction!.isNotEmpty)) {
          likedPosts.add(item.id ?? '');
        }
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
    debugPrint(" ${response.data}");
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
        "action": likedPosts.contains(postId) ? "unlike" : "like",
        "reaction_type": "like",
      });
      var action = response.data['action'];
      if (!mounted) return;
      setState(() {
        if (action == 'liked' || action == 'updated' || action == 'already_liked') {
          likedPosts.add(postId);
        } else if (action == 'unliked') {
          likedPosts.remove(postId);
        }
        likeCounts[postId] = response.data['total_likes'] ?? 0;
      });
    } catch (e) {
      debugPrint("Like error: $e");
    }
  }

  Future<void> _repost(String? postId, String? text, String? originalAuthor) async {
    if (postId == null || text == null || originalAuthor == null) return;
    String repostText = 'RT @$originalAuthor: $text';
    await sendMotivasi(repostText);
    _getData();
    if (mounted) {
      Flushbar(
        message: 'Berhasil diposting ulang',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        flushbarPosition: FlushbarPosition.TOP,
      ).show(context);
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

  // EPIC 4: Nested Comments Bottom Sheet with Reply Support
  void _showCommentSheet(
      BuildContext context, String? idMotivasi, String? postOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (builderContext, setSheetState) {
            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Komentar',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: FutureBuilder(
                      future: dio.get(
                          '$url/comment_get.php?id_motivasi=${idMotivasi ?? ""}'),
                      builder: (context, AsyncSnapshot snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        var commentsRaw = snapshot.data?.data?['data'] ?? [];

                        // EPIC 4: Build nested comment structure
                        List<Map<String, dynamic>> topLevelComments = [];
                        Map<String, List<Map<String, dynamic>>> repliesMap = {};

                        for (var c in commentsRaw) {
                          var comment = c as Map<String, dynamic>? ?? {};
                          if (comment['parent_id'] == null) {
                            topLevelComments.add(comment);
                          } else {
                            var parentId = comment['parent_id'].toString();
                            repliesMap.putIfAbsent(parentId, () => []);
                            repliesMap[parentId]!.add(comment);
                          }
                        }

                        if (topLevelComments.isEmpty) {
                          return const Center(
                              child: Text('Belum ada komentar'));
                        }

                        return ListView.builder(
                          itemCount: topLevelComments.length,
                          itemBuilder: (ctx, index) {
                            var comment =
                                topLevelComments[index];
                            var commentId = comment['id']?.toString() ?? '';
                            var replies = repliesMap[commentId] ?? [];
                            var isReplying = commentId == _replyingToCommentId;

                            return Column(
                              children: [
                                // Main comment
                                _buildCommentTile(
                                  context: builderContext,
                                  comment: comment,
                                  isReply: false,
                                  onReply: () {
                                    setSheetState(() {
                                      _replyingToCommentId = commentId;
                                      _replyingToUserName =
                                          comment['nama_user']?.toString() ??
                                              'User';
                                    });
                                  },
                                ),
                                // EPIC 4: Nested replies with left padding (Twitter-style)
                                ...replies.map((reply) => Padding(
                                      padding:
                                          const EdgeInsets.only(left: 40.0),
                                      child: _buildCommentTile(
                                        context: builderContext,
                                        comment: reply,
                                        isReply: true,
                                        onReply: () {
                                          setSheetState(() {
                                            _replyingToCommentId = commentId;
                                            _replyingToUserName =
                                                reply['nama_user']
                                                        ?.toString() ??
                                                    'User';
                                          });
                                        },
                                      ),
                                    )),
                                // Reply input field for this comment
                                if (isReplying)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 56.0, bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: commentController,
                                            decoration: InputDecoration(
                                              hintText:
                                                  "Balas @$_replyingToUserName...",
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          24)),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.send,
                                              color: Colors.blue, size: 20),
                                          onPressed: () async {
                                            if (commentController.text.isEmpty) {
                                              return;
                                            }
                                            try {
                                              await dio.post(
                                                  '$url/comment_post.php',
                                                  data: {
                                                    "id_motivasi":
                                                        idMotivasi ?? "",
                                                    "iduser":
                                                        widget.iduser ?? "",
                                                    "isi_komentar":
                                                        commentController.text,
                                                    "parent_id":
                                                        _replyingToCommentId,
                                                  });
                                              commentController.clear();
                                              setSheetState(() {
                                                _replyingToCommentId = null;
                                                _replyingToUserName = null;
                                              });
                                              Navigator.pop(sheetContext);
                                              _showCommentSheet(context,
                                                  idMotivasi, postOwnerId);
                                            } catch (e) {
                                              Flushbar(
                                                message:
                                                    "Gagal mengirim balasan",
                                                duration:
                                                    const Duration(seconds: 2),
                                                backgroundColor: Colors.red,
                                                flushbarPosition:
                                                    FlushbarPosition.TOP,
                                              ).show(builderContext);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.grey, size: 20),
                                          onPressed: () {
                                            setSheetState(() {
                                              _replyingToCommentId = null;
                                              _replyingToUserName = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                const Divider(height: 1),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Main comment input field
                  if (_replyingToCommentId == null)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                              hintText: "Tulis komentar...",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
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
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              _showCommentSheet(
                                  context, idMotivasi, postOwnerId);
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

  // EPIC 4: Build individual comment tile with profile picture
  Widget _buildCommentTile({
    required BuildContext context,
    required Map<String, dynamic> comment,
    required bool isReply,
    required VoidCallback onReply,
  }) {
    String? foto = comment['foto']?.toString();
    String? namaUser = comment['nama_user']?.toString() ?? 'User';

    return ListTile(
      contentPadding: EdgeInsets.only(left: isReply ? 8 : 0, right: 8),
      leading: _buildProfileAvatar(foto, namaUser, size: isReply ? 28 : 40),
      title: Text(
        namaUser,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isReply ? 13 : 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment['isi_komentar']?.toString() ?? '',
            style: TextStyle(fontSize: isReply ? 13 : 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatDate(DateTime.tryParse(
                    comment['tanggal_input']?.toString() ?? '')),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              if (!isReply) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onReply,
                  child: const Text(
                    'Balas',
                    style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // EPIC 1: Profile avatar builder with NetworkImage and fallback
  Widget _buildProfileAvatar(String? foto, String? nama, {double size = 40}) {
    if (foto != null && foto.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.blue.shade100,
        backgroundImage:
            NetworkImage('$url/uploads/$foto'),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        (nama ?? 'U')[0].toUpperCase(),
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  // EPIC 4: Reply state
  String? _replyingToCommentId;
  String? _replyingToUserName;

  TextEditingController isiController = TextEditingController();
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserFoto();
    getData();
    _getData();
  }

  // EPIC 1: Load current user's photo from SharedPreferences
  Future<void> _loadCurrentUserFoto() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserFoto = prefs.getString('foto');
    });
  }

  Widget _buildHomeScreen() {
    return RefreshIndicator(
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
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w500)),
                        Text(widget.roleId == '1' ? ' [Admin]' : ' [Member]',
                            style: TextStyle(
                              color: widget.roleId == '1'
                                  ? Colors.red
                                  : Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            )),
                      ],
                    ),
                    TextButton(
                      child: const Icon(Icons.logout),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Login()));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // EPIC 1: Load current user's photo for input field
                            _buildProfileAvatar(currentUserFoto, widget.nama),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FormBuilderTextField(
                                controller: isiController,
                                name: "isi_motivasi",
                                decoration: InputDecoration(
                                  hintText: "Apa yang kamu pikirkan?",
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
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
                                    message:
                                        "Kolom motivasi tidak boleh kosong",
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.orange,
                                    flushbarPosition: FlushbarPosition.TOP,
                                  ).show(context);
                                  return;
                                }
                                await sendMotivasi(
                                        isiController.text.toString())
                                    .then((value) {
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder(
                  stream: getPostsStream(),
                  builder:
                      (context, AsyncSnapshot<List<MotivasiModel>> snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator());
                    }
                    if (snapshot.data!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(50),
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text("Belum ada motivasi",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        var item = snapshot.data![index];
                        bool isLiked = likedPosts.contains(item.id);
                        bool isSaved = savedPosts.contains(item.id);
                        bool isOwner = item.iduser == widget.iduser;
                        bool isAdmin = widget.roleId == '1';
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // EPIC 1: Profile picture from user table
                                    _buildProfileAvatar(
                                        item.foto, item.namaUser),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.namaUser ?? 'User',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15)),
                                          if (item.profesi != null &&
                                              item.profesi!.isNotEmpty)
                                            Text(item.profesi!,
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                          Text(_formatDate(item.tanggalInput),
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(item.isiMotivasi ?? '',
                                    style: const TextStyle(
                                        fontSize: 15, height: 1.4)),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Comment
                                      InkWell(
                                        onTap: () => _showCommentSheet(context, item.id, item.iduser),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                                              const SizedBox(width: 4),
                                              Text('${item.totalComments ?? 0}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Repost
                                      InkWell(
                                        onTap: () => _repost(item.id, item.isiMotivasi, item.namaUser),
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.repeat, color: Colors.grey, size: 20),
                                        ),
                                      ),
                                      // Like
                                      InkWell(
                                        onTap: () => _toggleLike(item.id),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                                                  color: isLiked ? Colors.red : Colors.grey, size: 20),
                                              const SizedBox(width: 4),
                                              Text('${likeCounts[item.id] ?? 0}',
                                                  style: TextStyle(color: isLiked ? Colors.red : Colors.grey, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Save
                                      InkWell(
                                        onTap: () => _toggleSave(item.id),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                                              color: isSaved ? Colors.orange : Colors.grey, size: 20),
                                        ),
                                      ),
                                      // Share
                                      InkWell(
                                        onTap: () {
                                          SharePlus.instance.share(ShareParams(
                                              text: 'Cek motivasi keren ini di Vigenesia: "${item.isiMotivasi}" - dari ${item.namaUser}'));
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.share, color: Colors.grey, size: 20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isOwner || isAdmin)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => EditPage(
                                                    id: item.id,
                                                    isiMotivasi: item.isiMotivasi),
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
                                              content: const Text(
                                                  "Apakah kamu yakin ingin menghapus motivasi ini?"),
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
                                                  child: const Text("Hapus",
                                                      style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScreen(),
          Follow(iduser: widget.iduser!),
          NotificationPage(iduser: widget.iduser!),
          const Profile(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_add), label: "Follow"),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: "Notification"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
