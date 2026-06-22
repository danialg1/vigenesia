import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../Models/motivasi_model.dart';
import '../Constant/const.dart';

class Follow extends StatefulWidget {
  final String? iduser;
  const Follow({Key? key, this.iduser}) : super(key: key);

  @override
  _FollowState createState() => _FollowState();
}

class _FollowState extends State<Follow> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _users = [];
  List<UserModel> _followers = [];
  List<UserModel> _following = [];
  Set<String> _followingIds = {};
  bool isLoading = true;
  var dio = Dio(BaseOptions(headers: {'ngrok-skip-browser-warning': '69420'}));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _loadUsers(),
      _loadFollowData(),
    ]);
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      var response = await dio
          .get('$url/users_get.php?current_user_id=${widget.iduser ?? ""}');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        var usersList = (response.data['data'] as List)
            .map((i) => UserModel.fromJson(i))
            .toList();
        if (!mounted) return;
        setState(() {
          _users = usersList;
          // Update following IDs set
          _followingIds = usersList
              .where((u) => u.isFollowing == true)
              .map((u) => u.id ?? '')
              .toSet();
        });
      }
    } catch (e) {
      debugPrint("Error loading users: $e");
    }
  }

  Future<void> _loadFollowData() async {
    try {
      var response =
          await dio.get('$url/follow_get.php?user_id=${widget.iduser ?? ""}');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        var data = response.data['data'];

        var followersList = (data['followers'] as List? ?? [])
            .map((i) => UserModel.fromJson(i))
            .toList();

        var followingList = (data['following'] as List? ?? [])
            .map((i) => UserModel.fromJson(i))
            .toList();

        if (!mounted) return;
        setState(() {
          _followers = followersList;
          _following = followingList;
        });
      }
    } catch (e) {
      debugPrint("Error loading follow data: $e");
    }
  }

  // EPIC 2: Toggle follow/unfollow
  Future<void> _toggleFollow(String? targetUserId) async {
    if (targetUserId == null || widget.iduser == null) return;

    try {
      var response = await dio.post('$url/follow_action.php', data: {
        "follower_id": widget.iduser,
        "following_id": targetUserId,
      });

      var action = response.data['action'];

      if (!mounted) return;
      setState(() {
        if (action == 'followed') {
          _followingIds.add(targetUserId);
        } else {
          _followingIds.remove(targetUserId);
        }
      });

      // Refresh follow data to update counts
      await _loadFollowData();
      await _loadUsers();
    } catch (e) {
      debugPrint("Follow error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // EPIC 1: Profile avatar builder
  Widget _buildProfileAvatar(String? foto, String? nama, {double size = 50}) {
    if (foto != null && foto.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.blue.shade100,
        backgroundImage:
            NetworkImage('http://10.0.2.2/vigenesia/uploads/$foto'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Follow"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1976D2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1976D2),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Discover Users
                _buildUsersList(),
                // Tab 2: Followers
                _buildFollowList(_followers, 'Belum ada followers'),
                // Tab 3: Following
                _buildFollowList(_following, 'Belum ada following'),
              ],
            ),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Belum ada pengguna",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          var user = _users[index];
          bool isFollowing = _followingIds.contains(user.id);
          bool isCurrentUser = user.id == widget.iduser;

          return ListTile(
            leading: _buildProfileAvatar(user.foto, user.nama),
            title: Text(
              user.nama ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.profesi != null && user.profesi!.isNotEmpty)
                  Text(
                    user.profesi!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                Text(
                  '${user.followerCount ?? 0} followers',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            trailing: isCurrentUser
                ? Chip(
                    label: const Text('You', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.grey[200],
                  )
                : ElevatedButton(
                    onPressed: () => _toggleFollow(user.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.grey[300]
                          : const Color(0xFF1976D2),
                      foregroundColor:
                          isFollowing ? Colors.black87 : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
            onTap: isCurrentUser ? null : () => _toggleFollow(user.id),
          );
        },
      ),
    );
  }

  Widget _buildFollowList(List<UserModel> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          var user = users[index];
          bool isFollowing = _followingIds.contains(user.id);
          bool isCurrentUser = user.id == widget.iduser;

          return ListTile(
            leading: _buildProfileAvatar(user.foto, user.nama),
            title: Text(
              user.nama ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: user.profesi != null && user.profesi!.isNotEmpty
                ? Text(
                    user.profesi!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  )
                : null,
            trailing: isCurrentUser
                ? null
                : ElevatedButton(
                    onPressed: () => _toggleFollow(user.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.grey[300]
                          : const Color(0xFF1976D2),
                      foregroundColor:
                          isFollowing ? Colors.black87 : Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      isFollowing ? 'Unfollow' : 'Follow',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
