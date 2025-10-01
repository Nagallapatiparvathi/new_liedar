import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const reactionsList = [
  {'emoji': '🤣', 'type': 'funny'},
  {'emoji': '😱', 'type': 'shocked'},
  {'emoji': '😭', 'type': 'sad'},
  {'emoji': '😡', 'type': 'angry'},
  {'emoji': '🤯', 'type': 'mindblown'},
  {'emoji': '❤', 'type': 'love'},
];

class UserProfilePage extends StatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String username = '';
  String? avatarUrl;
  int followers = 0;
  int following = 0;
  int streakCount = 0;
  bool isPrivate = false;
  bool isCurrentUser = false;
  bool isFollowing = false;
  bool canViewContent = false;
  bool isLoading = true;
  List<Map<String, dynamic>> posts = [];

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    final currentUserId = currentUser?.id;

    if (currentUserId == null) {
      setState(() {
        isLoading = false;
        canViewContent = false;
      });
      return;
    }

    final profile =
        await client
            .from('profiles')
            .select('username, avatar_url, streak_count, is_private')
            .eq('id', widget.userId)
            .maybeSingle();

    username = profile?['username'] ?? '';
    avatarUrl = profile?['avatar_url'];
    streakCount = profile?['streak_count'] ?? 0;
    isPrivate = profile?['is_private'] ?? false;

    final followersList = await client
        .from('follows')
        .select()
        .eq('followed_id', widget.userId)
        .eq('status', 'accepted');
    final followingList = await client
        .from('follows')
        .select()
        .eq('follower_id', widget.userId)
        .eq('status', 'accepted');
    followers = (followersList as List).length;
    following = (followingList as List).length;

    isCurrentUser = (currentUserId == widget.userId);

    final approvedFollow =
        await client
            .from('follows')
            .select()
            .eq('follower_id', currentUserId)
            .eq('followed_id', widget.userId)
            .eq('status', 'accepted')
            .maybeSingle();
    isFollowing = approvedFollow != null;

    canViewContent = !isPrivate || isCurrentUser || isFollowing;
    posts.clear();

    if (canViewContent) {
      final rawPosts = await client
          .from('lies')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      posts = List<Map<String, dynamic>>.from(
        rawPosts?.where((row) {
              if (row['is_anonymous'] == true) {
                return isCurrentUser;
              }
              return true;
            }).toList() ??
            [],
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _followUser() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return;
    try {
      await client.from('follows').insert({
        'follower_id': currentUser.id,
        'followed_id': widget.userId,
        'status': isPrivate ? 'pending' : 'accepted',
      });
      await loadProfile();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPrivate
                ? "Follow request sent. Wait for approval."
                : "You are now following $username!",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Follow failed: $e')));
    }
  }

  // Reaction Methods (copied/adapted from explore page)
  Future<String?> _getUserReaction(int lieId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final res =
        await Supabase.instance.client
            .from('reactions')
            .select('reaction_type')
            .eq('lie_id', lieId)
            .eq('user_id', user.id)
            .maybeSingle();
    return res != null && res['reaction_type'] != null
        ? res['reaction_type']
        : null;
  }

  Future<int> _getReactionCount(int lieId, String reactionType) async {
    final res = await Supabase.instance.client
        .from('reactions')
        .select('id')
        .eq('lie_id', lieId)
        .eq('reaction_type', reactionType);
    return (res as List).length;
  }

  Future<void> _reactToLie(int lieId, String reactionType) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('reactions')
        .delete()
        .eq('lie_id', lieId)
        .eq('user_id', user.id);
    try {
      await Supabase.instance.client.from('reactions').insert({
        'lie_id': lieId,
        'user_id': user.id,
        'reaction_type': reactionType,
      });
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reaction added!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reaction error: $e")));
    }
  }

  Widget _reactionRow(int lieId) {
    return FutureBuilder<String?>(
      future: _getUserReaction(lieId),
      builder: (context, snapshot) {
        final myReactionType = snapshot.data;
        return Wrap(
          spacing: 2,
          runSpacing: 3,
          children:
              reactionsList.map((reaction) {
                final emoji = reaction['emoji']!;
                final type = reaction['type']!;
                final isSelected = myReactionType == type;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      label: Text(emoji, style: TextStyle(fontSize: 16)),
                      selected: isSelected,
                      selectedColor: Colors.teal.withOpacity(0.25),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 0, horizontal: 7),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: Colors.teal, width: 1.0),
                      onSelected:
                          isSelected ? null : (_) => _reactToLie(lieId, type),
                    ),
                    SizedBox(width: 2),
                    FutureBuilder<int>(
                      future: _getReactionCount(lieId, type),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return Text(
                          '$count',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(username)),
      body: RefreshIndicator(
        onRefresh: loadProfile,
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null ? Icon(Icons.person, size: 42) : null,
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                username,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _profileStat(followers, "Followers"),
                SizedBox(width: 24),
                _profileStat(following, "Following"),
                SizedBox(width: 24),
                _profileStat(streakCount, "Streak"),
              ],
            ),
            SizedBox(height: 16),
            if (!isCurrentUser && !isFollowing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: ElevatedButton(
                  onPressed: _followUser,
                  child: Text(isPrivate ? "Request to Follow" : "Follow"),
                  style: ElevatedButton.styleFrom(minimumSize: Size(120, 40)),
                ),
              ),
            if (!canViewContent)
              Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  "This account is private. You need to follow and be accepted to see their posts.",
                  style: TextStyle(color: Colors.grey[700], fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            if (canViewContent) ...[
              Text(
                "Posts",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              if (posts.isEmpty)
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No posts available."),
                ),
              ...posts.map(
                (post) => Card(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(
                            post['lie_text'] ?? "—",
                            style: TextStyle(fontSize: 15, letterSpacing: 0.2),
                          ),
                          subtitle: Row(
                            children: [
                              if (post['category'] != null)
                                Text(
                                  post['category'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.teal,
                                  ),
                                ),
                              if (post['region'] != null) ...[
                                Text(" · "),
                                Text(
                                  post['region'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12.0,
                            top: 7.0,
                            bottom: 5.0,
                          ),
                          child: _reactionRow(post['id'] as int),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _profileStat(int stat, String label) {
    return Column(
      children: [
        Text(
          '$stat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}
