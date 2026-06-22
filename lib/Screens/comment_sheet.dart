import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:another_flushbar/flushbar.dart';
import '../Constant/const.dart';
import '../Models/motivasi_model.dart';

class CommentSheet extends StatefulWidget {
  final MotivasiModel post;
  final String currentUserId;
  final String? currentUserFoto;

  const CommentSheet({
    Key? key,
    required this.post,
    required this.currentUserId,
    this.currentUserFoto,
  }) : super(key: key);

  @override
  _CommentSheetState createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));
  TextEditingController commentController = TextEditingController();
  bool isLoading = true;
  List<Map<String, dynamic>> topLevelComments = [];
  Map<String, List<Map<String, dynamic>>> repliesMap = {};

  String? _replyingToCommentId;
  String? _replyingToUserName;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() => isLoading = true);
    try {
      var res = await dio.get('$url/comment_get.php?id_motivasi=${widget.post.id ?? ""}');
      var commentsRaw = res.data?['data'] ?? [];
      
      List<Map<String, dynamic>> tlc = [];
      Map<String, List<Map<String, dynamic>>> rMap = {};

      for (var c in commentsRaw) {
        var comment = c as Map<String, dynamic>? ?? {};
        if (comment['parent_id'] == null) {
          tlc.add(comment);
        } else {
          var parentId = comment['parent_id'].toString();
          rMap.putIfAbsent(parentId, () => []);
          rMap[parentId]!.add(comment);
        }
      }

      setState(() {
        topLevelComments = tlc;
        repliesMap = rMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching comments: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    if (commentController.text.trim().isEmpty) return;
    try {
      await dio.post('$url/comment_post.php', data: {
        "id_motivasi": widget.post.id ?? "",
        "iduser": widget.currentUserId,
        "isi_komentar": commentController.text.trim(),
        if (_replyingToCommentId != null) "parent_id": _replyingToCommentId,
      });
      commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });
      _fetchComments();
    } catch (e) {
      if (mounted) {
        Flushbar(
          message: "Gagal mengirim balasan",
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
        ).show(context);
      }
    }
  }

  Widget _buildProfileAvatar(String? foto, String? nama, {double size = 40}) {
    if (foto != null && foto.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          '$url/uploads/$foto',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackAvatar(nama, size),
        ),
      );
    }
    return _fallbackAvatar(nama, size);
  }

  Widget _fallbackAvatar(String? nama, double size) {
    String initial = (nama != null && nama.isNotEmpty) ? nama[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, {bool isReply = false}) {
    String? foto = comment['foto']?.toString();
    String? namaUser = comment['nama_user']?.toString() ?? 'User';
    var commentId = comment['id']?.toString() ?? '';

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 50 : 16, right: 16, top: 12, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileAvatar(foto, namaUser, size: isReply ? 32 : 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(namaUser, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 4),
                    Text('@${namaUser.toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 2),
                if (isReply)
                  Text('Membalas pengguna lain', style: TextStyle(color: Colors.blue.shade400, fontSize: 13)),
                const SizedBox(height: 4),
                Text(comment['isi_komentar']?.toString() ?? '', style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _replyingToCommentId = isReply ? comment['parent_id']?.toString() : commentId;
                          _replyingToUserName = namaUser;
                        });
                      },
                      child: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Posting balasan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      // Original Post Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                _buildProfileAvatar(widget.post.foto, widget.post.namaUser, size: 40),
                                if (topLevelComments.isNotEmpty)
                                  Container(
                                    width: 2,
                                    height: 40,
                                    color: Colors.grey.shade300,
                                    margin: const EdgeInsets.only(top: 8),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(widget.post.namaUser ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      const SizedBox(width: 4),
                                      Text('@${(widget.post.namaUser ?? 'user').toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(widget.post.isiMotivasi ?? '', style: const TextStyle(fontSize: 15)),
                                  if (widget.post.fotoMotivasi != null && widget.post.fotoMotivasi!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network('$url/uploads/${widget.post.fotoMotivasi}', fit: BoxFit.cover, height: 150, width: double.infinity),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text('Membalas @${(widget.post.namaUser ?? 'user').toLowerCase().replaceAll(' ', '')}', style: TextStyle(color: Colors.blue.shade400, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Comments
                      ...topLevelComments.map((comment) {
                        var commentId = comment['id']?.toString() ?? '';
                        var replies = repliesMap[commentId] ?? [];
                        return Column(
                          children: [
                            _buildCommentTile(comment, isReply: false),
                            ...replies.map((reply) => _buildCommentTile(reply, isReply: true)),
                            const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                      const SizedBox(height: 80), // Padding for bottom input
                    ],
                  ),
          ),
          // Sticky Bottom Input Area
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 52),
                    child: Row(
                      children: [
                        Text("Membalas @${_replyingToUserName!.toLowerCase().replaceAll(' ', '')}", style: TextStyle(color: Colors.blue.shade400, fontSize: 13)),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() {
                            _replyingToCommentId = null;
                            _replyingToUserName = null;
                          }),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildProfileAvatar(widget.currentUserFoto, 'Me', size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: commentController,
                          maxLines: 4,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: "Posting balasan Anda",
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitComment,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        backgroundColor: Colors.blue,
                        elevation: 0,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
