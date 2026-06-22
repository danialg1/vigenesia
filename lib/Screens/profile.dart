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
import 'image_viewer.dart';
import 'comment_sheet.dart';
import 'create_post.dart';

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
  void _showRepostOptions(BuildContext context, MotivasiModel post) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('Posting Ulang'),
                onTap: () {
                  Navigator.pop(context);
                  _repost(post.id, post.isiMotivasi, post.namaUser);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Kutipan'),
                onTap: () async {
                  Navigator.pop(context);
                  bool? result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePostScreen(
                        iduser: iduser ?? '',
                        repostId: post.id,
                        originalPostData: {
                          'nama_user': post.namaUser,
                          'isi_motivasi': post.isiMotivasi,
                          'foto_motivasi': post.fotoMotivasi,
                        },
                      ),
                    ),
                  );
                  if (result == true) {
                    _refreshPosts();
                  }
                },
              ),
            ],
          ),
        );
      },
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

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [Colors.blueGrey.shade900, Colors.black]
                        : [const Color(0xFF4FC3F7), const Color(0xFF1976D2)],
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
                            return InkWell(
                              onTap: () {
                                // optional: go to detail post
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.repostId != null && item.isiMotivasi!.startsWith('RT '))
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8, left: 32),
                                        child: Row(
                                          children: [
                                            Icon(Icons.repeat, color: Colors.grey, size: 14),
                                            SizedBox(width: 8),
                                            Text('Kamu memposting ulang', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildProfileAvatar(item.foto, item.namaUser, size: 40),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Text(item.namaUser ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                        const SizedBox(width: 4),
                                                        Flexible(
                                                          child: Text('@${(item.namaUser ?? "user").toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: Colors.grey, fontSize: 14), overflow: TextOverflow.ellipsis),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        const Text('·', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                                        const SizedBox(width: 4),
                                                        Text(_formatDate(item.tanggalInput), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                                                    padding: EdgeInsets.zero,
                                                    onSelected: (value) async {
                                                      if (value == 'edit') {
                                                        Navigator.push(context, MaterialPageRoute(builder: (context) => EditPage(id: item.id, isiMotivasi: item.isiMotivasi))).then((_) => _refreshPosts());
                                                      } else if (value == 'delete') {
                                                        _showDeleteDialog(context, item.id);
                                                      }
                                                    },
                                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                                      const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                                                      const PopupMenuItem<String>(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(item.isiMotivasi ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
                                              
                                              if (item.fotoMotivasi != null && item.fotoMotivasi!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 12),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewer(imageUrl: '$url/uploads/${item.fotoMotivasi}', heroTag: 'profile_img_${item.id}')));
                                                    },
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(16),
                                                      child: Hero(
                                                        tag: 'profile_img_${item.id}',
                                                        child: Image.network(
                                                          '$url/uploads/${item.fotoMotivasi}',
                                                          width: double.infinity,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                              // Nested Original Post (Quote Tweet)
                                              if (item.repostId != null && item.originalPost != null && !(item.isiMotivasi!.startsWith('RT ')))
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 12),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: Theme.of(context).dividerColor),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Padding(
                                                          padding: const EdgeInsets.all(12),
                                                          child: Row(
                                                            children: [
                                                              _buildProfileAvatar(item.originalPost!['foto']?.toString(), item.originalPost!['nama_user']?.toString(), size: 20),
                                                              const SizedBox(width: 8),
                                                              Text(item.originalPost!['nama_user']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                              const SizedBox(width: 4),
                                                              Text('@${(item.originalPost!['nama_user']?.toString() ?? "user").toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                            ],
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                                          child: Text(item.originalPost!['isi_motivasi']?.toString() ?? '', style: const TextStyle(fontSize: 14)),
                                                        ),
                                                        if (item.originalPost!['foto_motivasi'] != null && item.originalPost!['foto_motivasi'].toString().isNotEmpty)
                                                          GestureDetector(
                                                            onTap: () {
                                                              Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewer(imageUrl: '$url/uploads/${item.originalPost!['foto_motivasi']}', heroTag: 'profile_quote_img_${item.id}')));
                                                            },
                                                            child: ClipRRect(
                                                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                                              child: Hero(
                                                                tag: 'profile_quote_img_${item.id}',
                                                                child: Image.network(
                                                                  '$url/uploads/${item.originalPost!['foto_motivasi']}',
                                                                  width: double.infinity,
                                                                  fit: BoxFit.cover,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),

                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  // Comment
                                                  InkWell(
                                                    onTap: () {
                                                      showModalBottomSheet(
                                                        context: context,
                                                        isScrollControlled: true,
                                                        backgroundColor: Colors.transparent,
                                                        builder: (context) => CommentSheet(
                                                          post: item,
                                                          currentUserId: iduser ?? '',
                                                          currentUserFoto: foto,
                                                        ),
                                                      ).then((_) => _refreshPosts());
                                                    },
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 18),
                                                        const SizedBox(width: 4),
                                                        Text('${item.totalComments ?? 0}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                      ],
                                                    ),
                                                  ),
                                                  // Repost
                                                  InkWell(
                                                    onTap: () => _showRepostOptions(context, item),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.repeat, color: Colors.grey, size: 18),
                                                        const SizedBox(width: 4),
                                                        Text('${item.totalReposts ?? 0}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                                      ],
                                                    ),
                                                  ),
                                                  // Like
                                                  InkWell(
                                                    onTap: () => _toggleLike(item.id),
                                                    child: Row(
                                                      children: [
                                                        Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey, size: 18),
                                                        const SizedBox(width: 4),
                                                        Text('${likeCounts[item.id] ?? 0}', style: TextStyle(color: isLiked ? Colors.red : Colors.grey, fontSize: 13)),
                                                      ],
                                                    ),
                                                  ),
                                                  // Save
                                                  InkWell(
                                                    onTap: () => _toggleSave(item.id),
                                                    child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: isSaved ? Colors.blue : Colors.grey, size: 18),
                                                  ),
                                                  // Share
                                                  InkWell(
                                                    onTap: () {
                                                      SharePlus.instance.share(ShareParams(text: 'Cek motivasi ini: "${item.isiMotivasi}" - dari ${item.namaUser}'));
                                                    },
                                                    child: const Icon(Icons.share, color: Colors.grey, size: 18),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Post"),
        content: const Text("Apakah kamu yakin ingin menghapus post ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                var response = await dio.delete(
                  '$url/motivasi_delete.php',
                  data: {"id": postId},
                );
                if (response.statusCode == 200 && response.data['status'] == 'success') {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Post berhasil dihapus"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {
                      userPosts.removeWhere((item) => item.id == postId);
                    });
                  }
                } else {
                  throw Exception('Failed to delete on server');
                }
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
