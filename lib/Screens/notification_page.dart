import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../Models/motivasi_model.dart';
import '../Constant/const.dart';

class NotificationPage extends StatefulWidget {
  final String? iduser;
  const NotificationPage({Key? key, this.iduser}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool isLoading = true;
  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    try {
      var response = await dio.get('$url/notif_get.php?user_id=${widget.iduser ?? ""}');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        var notifList = (response.data['data'] as List)
            .map((i) => NotificationModel.fromJson(i))
            .toList();
        setState(() {
          _notifications = notifList;
          _unreadCount = response.data['unread_count'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading notifications: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _markAsRead(String? notifId) async {
    if (notifId == null) return;
    try {
      await dio.post('$url/notif_read.php', data: {
        "notif_id": notifId,
      });
      await _loadNotifications();
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Baru saja';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h lalu';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  // EPIC 1: Profile avatar builder
  Widget _buildProfileAvatar(String? foto, String? nama, {double size = 40}) {
    if (foto != null && foto.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: NetworkImage('http://10.0.2.2/vigenesia/uploads/$foto'),
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

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'reply':
        return Icons.reply;
      case 'follow':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'reply':
        return Colors.green;
      case 'follow':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Notification"),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadNotifications,
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Belum ada notifikasi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Notifikasi akan muncul di sini",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      var notif = _notifications[index];
                      bool isRead = notif.isRead ?? false;

                      return InkWell(
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(notif.id);
                          }
                        },
                        child: Container(
                          color: isRead ? null : Colors.blue.withValues(alpha: 0.05),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                _buildProfileAvatar(
                                  notif.actorFoto,
                                  notif.actorNama,
                                  size: 48,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: _getNotificationColor(notif.type),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(notif.type),
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              notif.message ?? 'New notification',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 14,
                              ),
 ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (notif.postContent != null && notif.postContent!.isNotEmpty)
                                  Text(
                                    notif.postContent!.length > 50
                                        ? '${notif.postContent!.substring(0, 50)}...'
                                        : notif.postContent!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(notif.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            trailing: !isRead
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
