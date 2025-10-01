import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class LieChatUsersPage extends StatefulWidget {
  final String currentUserId;
  const LieChatUsersPage({Key? key, required this.currentUserId})
    : super(key: key);

  @override
  _LieChatUsersPageState createState() => _LieChatUsersPageState();
}

class _LieChatUsersPageState extends State<LieChatUsersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingFollowers = true;
  bool _isLoadingFollowing = true;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchFollowers();
    fetchFollowing();
  }

  Future<void> fetchFollowers() async {
    setState(() => _isLoadingFollowers = true);
    try {
      final response = await Supabase.instance.client
          .from('follows')
          .select(
            'follower_id, status, profiles:follower_id (id, username, avatar_url)',
          )
          .eq('followed_id', widget.currentUserId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final dataList = response as List<dynamic>? ?? [];

      final followers =
          dataList.map<Map<String, dynamic>>((item) {
            final profile = (item['profiles'] ?? {}) as Map<String, dynamic>;
            return {
              'id': item['follower_id'],
              'status': item['status'],
              'username': profile['username'] ?? 'Unknown',
              'avatar_url': profile['avatar_url'],
            };
          }).toList();

      setState(() {
        _followers = followers;
      });
    } catch (e) {
      debugPrint('Error fetching followers: $e');
      setState(() {
        _followers = [];
      });
    } finally {
      setState(() => _isLoadingFollowers = false);
    }
  }

  Future<void> fetchFollowing() async {
    setState(() => _isLoadingFollowing = true);
    try {
      final response = await Supabase.instance.client
          .from('follows')
          .select(
            'followed_id, status, profiles:followed_id (id, username, avatar_url)',
          )
          .eq('follower_id', widget.currentUserId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      final dataList = response as List<dynamic>? ?? [];

      final following =
          dataList.map<Map<String, dynamic>>((item) {
            final profile = (item['profiles'] ?? {}) as Map<String, dynamic>;
            return {
              'id': item['followed_id'],
              'status': item['status'],
              'username': profile['username'] ?? 'Unknown',
              'avatar_url': profile['avatar_url'],
            };
          }).toList();

      setState(() {
        _following = following;
      });
    } catch (e) {
      debugPrint('Error fetching following: $e');
      setState(() {
        _following = [];
      });
    } finally {
      setState(() => _isLoadingFollowing = false);
    }
  }

  void openChat(Map<String, dynamic> user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChatPage(
              currentUserId: widget.currentUserId,
              otherUserId: user['id'],
              otherUsername: user['username'],
              otherAvatarUrl: user['avatar_url'],
            ),
      ),
    );
  }

  Widget buildUserList(List<Map<String, dynamic>> users, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final username = user['username'] as String;
        final avatarUrl = user['avatar_url'] as String?;
        return ListTile(
          leading:
              (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl))
                  : CircleAvatar(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                    ),
                  ),
          title: Text(username),
          onTap: () => openChat(user),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LieChat Users'),
        backgroundColor: Colors.deepOrange,
        leading: const BackButton(),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Followers'), Tab(text: 'Following')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildUserList(_followers, _isLoadingFollowers),
          buildUserList(_following, _isLoadingFollowing),
        ],
      ),
    );
  }
}
