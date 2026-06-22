import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../Models/motivasi_model.dart';
import '../Constant/const.dart';
import 'edit_page.dart';
import 'edit_profile.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:intl/intl.dart';

class Profile extends StatefulWidget {
  const Profile({Key? key}) : super(key: key);

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  String? iduser;
  String? nama;
  String? profesi;
  String? foto;
  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));
  List<MotivasiModel> userPosts = [];
  bool isLoading = true;
  Set<String> likedPosts = {};
  Set<String> savedPosts = {};
  Map<String, int> likeCounts = {};

  // EPIC 2: Real stats from database
  int totalFollowers = 0;
  int totalFollowing = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      iduser = prefs.getString('iduser');
      nama = prefs.getString('nama');
      profesi = prefs.getString('profesi');
      foto = prefs.getString('foto');
    });
    await _loadUserPosts();
    await _loadStats(); // EPIC 2: Load real stats
  }

  // EPIC 2: Load followers/following stats from database
  Future<void> _loadStats() async {
    if (iduser == null) return;
    try {
      var response = await dio.get('$url/profile_get.php?user_id=$iduser');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        var data = response.data['data'];
        setState(() {
          totalFollowers = int.tryParse(data['total_followers']?.toString() ?? '0') ?? 0;
          totalFollowing = int.tryParse(data['total_following']?.toString() ?? '0') ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
    }
  }

  Future<List<MotivasiModel>> getData({bool fromCache = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (fromCache) {
      String? cachedData = prefs.getString('cached_profile_posts_$iduser');
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
          return listUsers;
        } catch (e) {
          debugPrint("Cache error: $e");
        }
      }
      return [];
    }

    try {
      var response = await dio.get('$url/motivasi_get.php?user_id=${iduser ?? ""}&current_user_id=${iduser ?? ""}');
      debugPrint("Profile getData: ${response.data}");
      if (response.statusCode == 200) {
        prefs.setString('cached_profile_posts_$iduser', json.encode(response.data));
        var motivasiList = (response.data['data'] ?? []) as List;
        var listUsers = motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
        for (var item in listUsers) {
          likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
          if (item.isLiked == true || (item.userReaction != null && item.userReaction!.isNotEmpty)) {
            likedPosts.add(item.id ?? '');
          }
        }
        return listUsers;
      }
    } catch (e) {
      debugPrint("Error load posts: $e");
    }
    return [];
  }

  Future<void> _loadUserPosts() async {
    setState(() => isLoading = true);
    
    // Offline-first: load from cache
    var cachedPosts = await getData(fromCache: true);
    if (cachedPosts.isNotEmpty) {
      setState(() {
        userPosts = cachedPosts;
        isLoading = false;
      });
    }

    // Load from server
    var allPosts = await getData(fromCache: false);
    if (mounted) {
      setState(() {
        userPosts = allPosts;
        isLoading = false;
      });
    }
  }

  Future<void> _refreshPosts() async {
    await _loadUserPosts();
    await _loadStats(); // EPIC 2: Refresh stats too
  }

  void _toggleLike(String? postId) async {
    if (postId == null) return;
    try {
      var response = await dio.post('$url/like_action.php', data: {
        "id_motivasi": postId,
        "iduser": iduser ?? "",
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
      // Update local model
      int idx = userPosts.indexWhere((item) => item.id == postId);
      if (idx != -1) {
        setState(() {
          var item = userPosts[idx];
          userPosts[idx] = MotivasiModel(
            id: item.id,
            isiMotivasi: item.isiMotivasi,
            idKategori: item.idKategori,
            tanggalInput: item.tanggalInput,
            tanggalUpdate: item.tanggalUpdate,
            iduser: item.iduser,
            namaUser: item.namaUser,
            foto: item.foto,
            totalLikes: (likeCounts[postId] ?? 0).toString(),
            isLiked: likedPosts.contains(postId),
            userReaction: null,
            totalComments: item.totalComments,
          );
        });
      }
    } catch (e) {
      debugPrint("Like error: $e");
    }
  }

  Future<void> _repost(String? postId, String? text, String? originalAuthor) async {
    if (postId == null || text == null || originalAuthor == null) return;
    String repostText = 'RT @$originalAuthor: $text';
    Map<String, dynamic> body = {
      "isi_motivasi": repostText,
      "iduser": iduser,
    };
    try {
      await dio.post("$url/motivasi_post.php", data: body);
      _refreshPosts();
      if (mounted) {
        Flushbar(
          message: 'Berhasil diposting ulang',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    } catch (e) {
      debugPrint("Repost error: $e");
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

  // EPIC 4: Nested Comments Bottom Sheet with Reply Support
  void _showCommentSheet(BuildContext context, String? idMotivasi, String? postOwnerId) {
    TextEditingController commentController = TextEditingController();
    String? replyingToCommentId;
    String? replyingToUserName;

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
                          return const Center(child: Text('Belum ada komentar'));
                        }

                        return ListView.builder(
                          itemCount: topLevelComments.length,
                          itemBuilder: (ctx, index) {
                            var comment = topLevelComments[index];
                            var commentId = comment['id']?.toString() ?? '';
                            var replies = repliesMap[commentId] ?? [];
                            var isReplying = commentId == replyingToCommentId;

                            return Column(
                              children: [
                                // Main comment
                                _buildCommentTile(
                                  context: builderContext,
                                  comment: comment,
                                  isReply: false,
                                  onReply: () {
                                    setSheetState(() {
                                      replyingToCommentId = commentId;
                                      replyingToUserName = comment['nama_user']?.toString() ?? 'User';
                                    });
                                  },
                                ),
                                // EPIC 4: Nested replies with left padding (Twitter-style)
                                ...replies.map((reply) =>
 Padding(
                                    padding: const EdgeInsets.only(left: 40.0),
                                    child: _buildCommentTile(
                                      context: builderContext,
                                      comment: reply,
                                      isReply: true,
                                      onReply: () {
                                        setSheetState(() {
                                          replyingToCommentId = commentId;
                                          replyingToUserName = reply['nama_user']?.toString() ?? 'User';
                                        });
                                      },
                                    ),
                                  )
                                ),
                                // Reply input field for this comment
                                if (isReplying)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 56.0, bottom: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: commentController,
                                            decoration: InputDecoration(
                                              hintText: "Balas @$replyingToUserName...",
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.send, color: Colors.blue, size: 20),
                                          onPressed: () async {
                                            if (commentController.text.isEmpty) return;
                                            try {
                                              await dio.post('$url/comment_post.php', data: {
                                                "id_motivasi": idMotivasi ?? "",
                                                "iduser": iduser ?? "",
                                                "isi_komentar": commentController.text,
                                                "parent_id": replyingToCommentId,
                                              });
                                              commentController.clear();
                                              setSheetState(() {
                                                replyingToCommentId = null;
                                                replyingToUserName = null;
                                              });
                                              Navigator.pop(sheetContext);
                                              _showCommentSheet(context, idMotivasi, postOwnerId);
                                            } catch (e) {
                                              Flushbar(
                                                message: "Gagal mengirim balasan",
                                                duration: const Duration(seconds: 2),
                                                backgroundColor: Colors.red,
                                                flushbarPosition: FlushbarPosition.TOP,
                                              ).show(builderContext);
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                          onPressed: () {
                                            setSheetState(() {
                                              replyingToCommentId = null;
                                              replyingToUserName = null;
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
                  if (replyingToCommentId == null)
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
                                "iduser": iduser ?? "",
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
                _formatDateTime(DateTime.tryParse(comment['tanggal_input']?.toString() ?? '')),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              if (!isReply) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onReply,
                  child: const Text(
                    'Balas',
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w500),
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
        backgroundImage: NetworkImage('$url/uploads/$foto'),
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Profil
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                  ),
                ),
                child: Column(
                  children: [
                    // EPIC 1: Avatar with profile picture
                    _buildProfileAvatar(foto, nama, size: 100),
                    const SizedBox(height: 16),
                    // Nama
                    Text(
                      nama ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Profesi
                    Text(
                      profesi ?? '-',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Tombol Edit Profile
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EditProfile()),
                        ).then((value) {
                          if (value == true) {
                            _loadUserData(); // Refresh data after edit
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Profil berhasil diupdate"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("Edit Profile"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1976D2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // EPIC 2: Stats Row with real database numbers
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(userPosts.length.toString(), 'Posts'),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _buildStatItem(totalFollowers.toString(), 'Followers'),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _buildStatItem(totalFollowing.toString(), 'Following'),
                  ],
                ),
              ),
              const Divider(),
              // Title My Posts
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.article, color: Color(0xFF1976D2)),
                    SizedBox(width: 8),
                    Text(
                      'My Posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // List Posts
              isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    )
                  : userPosts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(50),
                          child: Column(
                            children: [
                              Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                "Belum ada post",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: userPosts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            var item = userPosts[index];
                            bool isLiked = likedPosts.contains(item.id);
                            bool isSaved = savedPosts.contains(item.id);
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
                                        // EPIC 1: Profile picture from user table
                                        _buildProfileAvatar(item.foto, item.namaUser),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.namaUser ?? 'User',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                _formatDate(item.tanggalInput),
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton(
                                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, size: 20),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, size: 20, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EditPage(
                                                    id: item.id,
                                                    isiMotivasi: item.isiMotivasi,
                                                  ),
                                                ),
                                              ).then((_) => _refreshPosts());
                                            } else if (value == 'delete') {
                                              _showDeleteDialog(context, item.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      item.isiMotivasi ?? '',
                                      style: const TextStyle(fontSize: 15, height: 1.4),
                                    ),
                                    const SizedBox(height: 12),
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
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1976D2),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, String? postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Post"),
        content: const Text("Apakah kamu yakin ingin menghapus post ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await dio.delete(
                  '$url/motivasi_delete.php',
                  data: {"id": postId},
                  options: Options(
                    contentType: Headers.formUrlEncodedContentType,
                    headers: {"Content-type": "application/json"},
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Post berhasil dihapus"),
                    backgroundColor: Colors.green,
                  ),
                );
                _refreshPosts();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Gagal menghapus: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
