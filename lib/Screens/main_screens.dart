// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/motivasi_model.dart';
import '../Screens/edit_page.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'login.dart';
import 'follow.dart';
import 'notification_page.dart';
import 'profile.dart';
import 'create_post.dart';
import 'image_viewer.dart';
import 'comment_sheet.dart';
import '../main.dart';
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
  List<MotivasiModel> listUsers = [];
  bool isLoading = true;

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

  Future<void> _getData() async {
    setState(() => isLoading = true);
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_main_posts');
    if (cachedData != null) {
      try {
        var jsonData = json.decode(cachedData);
        var motivasiList = (jsonData['data'] ?? []) as List;
        var users = motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
        if (mounted) {
          setState(() {
            listUsers = users;
            for (var item in listUsers) {
              likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
              if (item.isLiked == true || (item.userReaction != null && item.userReaction!.isNotEmpty)) {
                likedPosts.add(item.id ?? '');
              }
            }
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Cache error: $e");
      }
    }

    try {
      var response = await dio.get('$url/motivasi_get.php?iduser=${widget.iduser ?? ""}&current_user_id=${widget.iduser ?? ""}');
      if (response.statusCode == 200) {
        prefs.setString('cached_main_posts', json.encode(response.data));
        var motivasiList = (response.data['data'] ?? []) as List;
        var users = motivasiList.map((i) => MotivasiModel.fromJson(i)).toList();
        if (mounted) {
          setState(() {
            listUsers = users;
            for (var item in listUsers) {
              likeCounts[item.id ?? ''] = int.parse(item.totalLikes ?? '0');
              if (item.isLiked == true || (item.userReaction != null && item.userReaction!.isNotEmpty)) {
                likedPosts.add(item.id ?? '');
              }
            }
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<MotivasiModel>> getData() async {
    await _getData();
    return listUsers;
  }

  Future<bool> deletePost(String id) async {
    try {
      var response = await dio.delete('$url/motivasi_delete.php',
          data: {"id": id});
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Delete Error: $e");
      return false;
    }
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

  void _showRepostOptions(BuildContext context, MotivasiModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
                  _executeRepost(item.id);
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
                        iduser: widget.iduser!,
                        repostId: item.id,
                        originalPostData: {
                          'nama_user': item.namaUser,
                          'isi_motivasi': item.isiMotivasi,
                          'foto_motivasi': item.fotoMotivasi,
                        },
                      ),
                    ),
                  );
                  if (result == true) {
                    _getData();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeRepost(String? postId) async {
    if (postId == null) return;
    try {
      var formData = FormData.fromMap({
        'iduser': widget.iduser,
        'isi_motivasi': '',
        'repost_id': postId,
      });
      var response = await dio.post('$url/motivasi_post.php', data: formData);
      if (response.statusCode == 200) {
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
    } catch (e) {
      debugPrint("Error reposting: $e");
    }
  }

  Future<void> _toggleSave(String? postId) async {
    if (postId == null) return;
    try {
      var response = await dio.post('$url/bookmark_action.php', data: {
        'id_motivasi': postId,
        'iduser': widget.iduser,
      });
      if (response.statusCode == 200) {
        _getData();
      }
    } catch (e) {
      debugPrint("Error toggling bookmark: $e");
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
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
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    if (isLoading && listUsers.isEmpty) {
                      return const Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator());
                    }
                    if (listUsers.isEmpty) {
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
                      itemCount: listUsers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        var item = listUsers[index];
                        bool isLiked = likedPosts.contains(item.id);
                        bool isSaved = savedPosts.contains(item.id);
                        bool isOwner = item.iduser == widget.iduser;
                        bool isAdmin = widget.roleId == '1';
                        return InkWell(
                          onTap: () {
                            // Navigate to detail post if needed later
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                            ),
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.repostId != null && item.isiMotivasi != null && item.isiMotivasi!.startsWith('RT '))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 36, bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.repeat, color: Colors.grey, size: 14),
                                        const SizedBox(width: 8),
                                        Text('${item.namaUser} memposting ulang', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildProfileAvatar(item.foto, item.namaUser),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(item.namaUser ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                                                    ),
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
                                              if (isOwner || isAdmin)
                                                PopupMenuButton<String>(
                                                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                                                  padding: EdgeInsets.zero,
                                                  onSelected: (value) async {
                                                    if (value == 'edit') {
                                                      Navigator.push(context, MaterialPageRoute(builder: (context) => EditPage(id: item.id, isiMotivasi: item.isiMotivasi))).then((_) => _getData());
                                                    } else if (value == 'delete') {
                                                      bool success = await deletePost(item.id!);
                                                      if (success && mounted) {
                                                        setState(() { listUsers.removeWhere((p) => p.id == item.id); });
                                                      }
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
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewer(imageUrl: '$url/uploads/${item.fotoMotivasi}', heroTag: 'image_${item.id}')));
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Hero(
                                                    tag: 'image_${item.id}',
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
                                                          Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewer(imageUrl: '$url/uploads/${item.originalPost!['foto_motivasi']}', heroTag: 'quote_image_${item.id}')));
                                                        },
                                                        child: ClipRRect(
                                                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                                          child: Hero(
                                                            tag: 'quote_image_${item.id}',
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
                                                      currentUserId: widget.iduser ?? '',
                                                      currentUserFoto: currentUserFoto,
                                                    ),
                                                  ).then((_) => _getData());
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

  void _showThemeSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: themeNotifier,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mode gelap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RadioListTile<ThemeMode>(
                    title: const Text('Nonaktif'),
                    value: ThemeMode.light,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (val) {
                      if (val != null) themeNotifier.setThemeMode(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Aktif'),
                    value: ThemeMode.dark,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (val) {
                      if (val != null) themeNotifier.setThemeMode(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Gunakan pengaturan perangkat'),
                    value: ThemeMode.system,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (val) {
                      if (val != null) themeNotifier.setThemeMode(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  const Text('Tema gelap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    title: const Text('Temaram'),
                    value: 'dim',
                    groupValue: themeNotifier.darkThemeType,
                    onChanged: (val) {
                      if (val != null) themeNotifier.setDarkThemeType(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    title: const Text('Lampu mati'),
                    value: 'black',
                    groupValue: themeNotifier.darkThemeType,
                    onChanged: (val) {
                      if (val != null) themeNotifier.setDarkThemeType(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Padding(
              padding: const EdgeInsets.all(2.0),
              child: _buildProfileAvatar(currentUserFoto, widget.nama, size: 32),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ce/X_logo_2023.svg/1200px-X_logo_2023.svg.png',
          height: 24,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          errorBuilder: (_, __, ___) => const Text("Vigenesia", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                    accountName: Text(widget.nama ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    accountEmail: Text('@${(widget.nama ?? 'user').toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: Colors.grey)),
                    currentAccountPicture: _buildProfileAvatar(currentUserFoto, widget.nama, size: 60),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const Profile()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Premium', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Komunitas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: const Text('Markah', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Pengaturan Tampilan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context);
                      _showThemeSettings(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreatePostScreen(iduser: widget.iduser!)),
                );
                if (result == true) {
                  _getData();
                }
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScreen(),
          Follow(iduser: widget.iduser!),
          NotificationPage(iduser: widget.iduser!),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: const Color(0xFF1976D2),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none), label: "Notification"),
        ],
      ),
    );
  }
}
