import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liedar/liechat_userlist_page.dart';
import 'package:liedar/main.dart' as main_lib;
import 'package:liedar/notifications_page.dart' as notif_lib;
import 'package:liedar/regionTrends.dart';
import 'package:liedar/streak_badges_page.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'settings.dart';
import 'exploreLies.dart';
import 'lieVault.dart';
import 'submit_lie_page.dart';
import 'truth_lie_game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  Widget _buildPage() {
    switch (_currentIndex) {
      case 0:
        return const HomeBody();
      case 1:
        return const ExploreLiesPage();
      case 2:
        return const StreakBadgesPage();
      case 3:
        return const RegionalTrendsPage();
      case 4:
        return const TruthLieGamePage();
      default:
        return const HomeBody();
    }
  }

  final Color primaryGreen = const Color(0xFF00A86B);
  final Color backgroundGreen = const Color(0xFFD8E4BC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGreen,
      body: _buildPage(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: backgroundGreen,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
              color: _currentIndex == 0 ? primaryGreen : Colors.grey,
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.explore,
              color: _currentIndex == 1 ? primaryGreen : Colors.grey,
            ),
            label: "Explore",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.emoji_events,
              color: _currentIndex == 2 ? primaryGreen : Colors.grey,
            ),
            label: "Streaks",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.map,
              color: _currentIndex == 3 ? primaryGreen : Colors.grey,
            ),
            label: "Trends",
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.games,
              color: _currentIndex == 4 ? primaryGreen : Colors.grey,
            ),
            label: "Game",
          ),
        ],
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  List<Map<String, dynamic>> stories = [];
  List<Map<String, dynamic>> leaderboard = [];
  int userScore = 0;

  bool loadingStories = true;
  bool loadingLeaderboard = true;
  bool loadingScore = true;

  Map<String, List<Map<String, dynamic>>> reactionsByStory = {};
  Map<String, List<Map<String, dynamic>>> userStoriesMap = {};
  List<String> userIds = [];

  Map<String, dynamic>? selectedStory;
  int selectedIndex = -1;
  int selectedStoryUserIndex = 0;
  int selectedStoryIndex = 0;

  final Color primaryGreen = const Color(0xFF00A86B);
  final Color backgroundGreen = const Color(0xFFD8E4BC);

  final List<String> quotes = [
    '“Great truths are often lies in disguise.”',
    '“A lie gets halfway around the world.”',
    '“Truth is rare but worth telling.”',
    '“Telling truth in difficult times is revolutionary.”',
  ];

  String get randomQuote {
    var valid = quotes.where((q) => q.isNotEmpty).toList();
    valid.shuffle();
    return valid.isNotEmpty ? valid.first : "Speak your truth...";
  }

  Map<String, DateTime> _todayRange() {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return {'start': start, 'end': end};
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_fetchStories(), _fetchLeaderboard(), _fetchScore()]);
  }

  Future<void> _fetchStories() async {
    setState(() => loadingStories = true);
    try {
      final data = await Supabase.instance.client
          .from('stories')
          .select('story_id, user_id, image_url, media_type, created_at')
          .order('created_at', ascending: false)
          .limit(50);

      stories = List<Map<String, dynamic>>.from(data);

      final userIdsSet =
          stories.map((story) => story['user_id'] as String).toSet().toList();

      final profilesData =
          userIdsSet.isEmpty
              ? []
              : await Supabase.instance.client
                  .from('profiles')
                  .select('id, username')
                  .inFilter('id', userIdsSet);

      final Map<String, String> userIdToUsername = {
        for (var profile in profilesData)
          profile['id']: profile['username'] ?? 'Unknown',
      };

      userStoriesMap.clear();
      userIds.clear();

      for (var story in stories) {
        final uid = story['user_id'].toString();
        final username = userIdToUsername[uid] ?? 'Unknown User';
        story['username'] = username;

        userStoriesMap.putIfAbsent(uid, () => []);
        userStoriesMap[uid]!.add(story);
      }

      userIds.addAll(userStoriesMap.keys);

      await _fetchReactionsForStories();
    } catch (e) {
      stories = [];
      reactionsByStory = {};
      userStoriesMap = {};
      userIds = [];
    }
    setState(() => loadingStories = false);
  }

  Future<void> _fetchReactionsForStories() async {
    reactionsByStory.clear();

    if (stories.isEmpty) return;

    try {
      final storyIds = stories.map((story) => story['story_id']).toList();

      final List<Map<String, dynamic>> data = await Supabase.instance.client
          .from('story_reactions')
          .select('story_id, user_id, reaction, profiles(username)')
          .filter('story_id', 'in', '(${storyIds.join(",")})');

      for (var reaction in data) {
        final storyId = reaction['story_id'].toString();
        reactionsByStory.putIfAbsent(storyId, () => []);
        reactionsByStory[storyId]!.add({
          'user_id': reaction['user_id'],
          'reaction': reaction['reaction'],
          'username': reaction['profiles']?['username'] ?? 'Unknown',
        });
      }
    } catch (e) {
      reactionsByStory = {};
    }
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => loadingLeaderboard = true);
    try {
      final range = _todayRange();
      final data = await Supabase.instance.client
          .from('leaderboard_scores')
          .select('score, username, country, profiles(avatar_url)')
          .gte('played_at', range['start']!.toIso8601String())
          .lt('played_at', range['end']!.toIso8601String())
          .order('score', ascending: false)
          .limit(10);

      leaderboard = List<Map<String, dynamic>>.from(data);
    } catch (_) {
      leaderboard = [];
    }
    setState(() => loadingLeaderboard = false);
  }

  Future<void> _fetchScore() async {
    setState(() => loadingScore = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      userScore = 0;
      setState(() => loadingScore = false);
      return;
    }
    try {
      final range = _todayRange();
      final data =
          await Supabase.instance.client
              .from('leaderboard_scores')
              .select('score')
              .eq('user_id', userId)
              .gte('played_at', range['start']!.toIso8601String())
              .lt('played_at', range['end']!.toIso8601String())
              .maybeSingle();
      userScore = data?['score'] ?? 0;
    } catch (_) {
      userScore = 0;
    }
    setState(() => loadingScore = false);
  }

  String _displayUsername(String uid) {
    final userStories = userStoriesMap[uid];
    if (userStories != null && userStories.isNotEmpty) {
      final username = userStories[0]['username'];
      if (username != null && username.toString().isNotEmpty) {
        return username.toString();
      }
    }

    final currentUser = Supabase.instance.client.auth.currentUser?.id;
    if (uid == currentUser) return "Me";

    return 'Unknown User';
  }

  Future<void> _uploadStory(BuildContext context, String uid) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.media);
      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      final extension = result.files.first.extension ?? 'jpg';
      final now = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'story_${uid}_$now.$extension';
      final isVideo = ['mp4', 'mov', 'avi'].contains(extension.toLowerCase());

      final bucket = Supabase.instance.client.storage.from('stories');
      await bucket.uploadBinary('stories/$uid/$fileName', fileBytes!);
      final publicUrl = bucket.getPublicUrl('stories/$uid/$fileName');

      final newStory = {
        'user_id': uid,
        'image_url': publicUrl,
        'media_type': isVideo ? 'video' : 'image',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final insertResponse =
          await Supabase.instance.client
              .from('stories')
              .insert(newStory)
              .select()
              .single();

      if (insertResponse == null) {
        throw Exception('Failed to insert story, response is null.');
      }

      final username =
          Supabase
              .instance
              .client
              .auth
              .currentUser
              ?.userMetadata?['username'] ??
          'Me';

      final localStory = {...insertResponse, 'username': username};

      setState(() {
        stories.insert(0, localStory);
        userStoriesMap.putIfAbsent(uid, () => []);
        userStoriesMap[uid]!.insert(0, localStory);
        if (!userIds.contains(uid)) {
          userIds.insert(0, uid);
        }
      });

      _fetchStories();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _addOrChangeReaction(String storyId, String reaction) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login")));
      return;
    }

    try {
      final existing =
          await Supabase.instance.client
              .from('story_reactions')
              .select()
              .eq('story_id', storyId)
              .eq('user_id', userId)
              .maybeSingle();

      if (existing == null) {
        await Supabase.instance.client.from('story_reactions').insert({
          'story_id': storyId,
          'user_id': userId,
          'reaction': reaction,
        });
      } else {
        await Supabase.instance.client
            .from('story_reactions')
            .update({'reaction': reaction})
            .eq('story_id', storyId)
            .eq('user_id', userId);
      }

      await _fetchReactionsForStories();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to react: $e")));
    }
  }

  Future<void> _deleteStory(String storyId) async {
    try {
      await Supabase.instance.client
          .from('story_reactions')
          .delete()
          .eq('story_id', storyId);
      await Supabase.instance.client
          .from('stories')
          .delete()
          .eq('story_id', storyId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Story deleted")));
      await _fetchStories();

      if (selectedStory != null &&
          selectedStory!['story_id'].toString() == storyId) {
        setState(() {
          selectedStory = null;
          selectedIndex = -1;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
    }
  }

  Widget buildReactionButtons(String storyId) {
    const icons = {
      'like': Icons.thumb_up,
      'love': Icons.favorite,
      'laugh': Icons.emoji_emotions,
      'surprised': Icons.sentiment_very_satisfied,
      'sad': Icons.sentiment_dissatisfied,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children:
          icons.entries.map((entry) {
            final reacted =
                reactionsByStory[storyId]?.any(
                  (e) =>
                      e['user_id'] ==
                          Supabase.instance.client.auth.currentUser?.id &&
                      e['reaction'] == entry.key,
                ) ??
                false;
            return IconButton(
              icon: Icon(
                entry.value,
                color: reacted ? primaryGreen : Colors.grey,
              ),
              onPressed: () => _addOrChangeReaction(storyId, entry.key),
              tooltip: entry.key,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32, minHeight: 32),
              iconSize: 24,
            );
          }).toList(),
    );
  }

  Widget buildReactionList(String storyId) {
    final reactions = reactionsByStory[storyId] ?? [];
    if (reactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          "No reactions yet",
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            reactions.map((react) {
              IconData icon;
              switch (react['reaction']) {
                case 'like':
                  icon = Icons.thumb_up;
                  break;
                case 'love':
                  icon = Icons.favorite;
                  break;
                case 'laugh':
                  icon = Icons.emoji_emotions;
                  break;
                case 'surprised':
                  icon = Icons.sentiment_very_satisfied;
                  break;
                case 'sad':
                  icon = Icons.sentiment_dissatisfied;
                  break;
                default:
                  icon = Icons.sentiment_neutral;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Icon(icon, color: primaryGreen, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        react['username'],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      react['reaction'],
                      style: TextStyle(fontSize: 13, color: primaryGreen),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  void _selectStoryByUserIndex(int idx) {
    if (idx < 0 || idx >= userIds.length) return;
    final uid = userIds[idx];
    final storiesOfUser = userStoriesMap[uid];
    if (storiesOfUser == null || storiesOfUser.isEmpty) return;

    setState(() {
      selectedIndex = idx;
      selectedStoryUserIndex = idx;
      selectedStoryIndex = 0;
      selectedStory = storiesOfUser.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGreen,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 4,
        title: Row(
          children: const [
            Icon(Icons.bolt, color: Colors.white),
            SizedBox(width: 8),
            Text(
              "LieDar",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => NotificationsPage()));
            },
            tooltip: "Notifications",
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
            tooltip: "Profile",
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
            tooltip: "Settings",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Stories row with add button
          SizedBox(
            height: 130,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: InkWell(
                    onTap: () {
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please login")),
                        );
                        return;
                      }
                      _uploadStory(context, user.id);
                    },
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: primaryGreen.withOpacity(0.8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Add Story",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child:
                      loadingStories
                          ? Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
                          )
                          : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: userIds.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, idx) {
                              final uid = userIds[idx];
                              final userStories = userStoriesMap[uid]!;
                              final firstStory = userStories.first;
                              final mediaUrl = firstStory['image_url'] ?? '';
                              final isVideo =
                                  firstStory['media_type'] == 'video';
                              final storyId = firstStory['story_id'].toString();

                              return SizedBox(
                                width: 130,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () => _selectStoryByUserIndex(idx),
                                      borderRadius: BorderRadius.circular(55),
                                      child: Stack(
                                        children: [
                                          // Outer circle border
                                          CircleAvatar(
                                            radius: 50,
                                            backgroundColor: primaryGreen,
                                            child: CircleAvatar(
                                              radius: 46,
                                              backgroundImage:
                                                  mediaUrl.isNotEmpty
                                                      ? NetworkImage(mediaUrl)
                                                      : null,
                                              backgroundColor: Colors.white,
                                              child:
                                                  mediaUrl.isEmpty
                                                      ? const Icon(
                                                        Icons.person,
                                                        size: 42,
                                                        color: Color(
                                                          0xFF00A86B,
                                                        ),
                                                      )
                                                      : null,
                                            ),
                                          ),

                                          // Story count badge
                                          if (userStories.length > 1)
                                            Positioned(
                                              top: -3,
                                              right: -3,
                                              child: CircleAvatar(
                                                radius: 14,
                                                backgroundColor: primaryGreen,
                                                child: Text(
                                                  '${userStories.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Video icon
                                          if (isVideo)
                                            const Positioned(
                                              bottom: 6,
                                              right: 6,
                                              child: Icon(
                                                Icons.play_circle_fill,
                                                color: Colors.white70,
                                                size: 30,
                                              ),
                                            ),

                                          // Three-dot menu inside story circle
                                          Positioned(
                                            top: 6,
                                            left: 6,
                                            child: CircleAvatar(
                                              radius: 13,
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.9),
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                  size: 20,
                                                  color: Colors.black87,
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'delete') {
                                                    final currentUser =
                                                        Supabase
                                                            .instance
                                                            .client
                                                            .auth
                                                            .currentUser;
                                                    if (currentUser == null ||
                                                        currentUser.id != uid) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            "You can only delete your own stories.",
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    showDialog(
                                                      context: context,
                                                      builder:
                                                          (ctx) => AlertDialog(
                                                            title: const Text(
                                                              'Delete Story',
                                                            ),
                                                            content: const Text(
                                                              'Are you sure you want to delete this story?',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () =>
                                                                        Navigator.of(
                                                                          ctx,
                                                                        ).pop(),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    ctx,
                                                                  ).pop();
                                                                  _deleteStory(
                                                                    storyId,
                                                                  );
                                                                },
                                                                child: const Text(
                                                                  'Delete',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                    );
                                                  }
                                                },
                                                itemBuilder:
                                                    (ctx) => const [
                                                      PopupMenuItem<String>(
                                                        value: 'delete',
                                                        child: Text(
                                                          'Delete Story',
                                                        ),
                                                      ),
                                                    ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _displayUsername(uid),
                                      style: TextStyle(
                                        fontWeight:
                                            selectedIndex == idx
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color:
                                            selectedIndex == idx
                                                ? primaryGreen
                                                : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
          if (selectedStory != null) ...[
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: PageView.builder(
                controller: PageController(
                  initialPage: selectedIndex >= 0 ? selectedIndex : 0,
                ),
                onPageChanged: (userIndex) {
                  setState(() {
                    selectedIndex = userIndex;
                  });
                },
                itemCount: userIds.length,
                itemBuilder: (context, userIndex) {
                  final uid = userIds[userIndex];
                  final storiesOfUser = userStoriesMap[uid]!;

                  return PageView.builder(
                    controller: PageController(initialPage: 0),
                    itemCount: storiesOfUser.length,
                    onPageChanged: (storyIndex) {
                      setState(() {
                        selectedStory = storiesOfUser[storyIndex];
                      });
                    },
                    itemBuilder: (context, storyIndex) {
                      final story = storiesOfUser[storyIndex];
                      final mediaUrl = story['image_url'] ?? '';
                      final isVideo = story['media_type'] == 'video';
                      final storyId = story['story_id'].toString();

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            // Media container
                            Container(
                              height: MediaQuery.of(context).size.height * 0.45,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child:
                                    isVideo
                                        ? VideoPlayerWidget(url: mediaUrl)
                                        : Image.network(
                                          mediaUrl,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          },
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return const Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 50,
                                              ),
                                            );
                                          },
                                        ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Reaction emoji buttons
                            buildReactionButtons(storyId),
                            const SizedBox(height: 14),

                            // List of users who reacted
                            Expanded(child: buildReactionList(storyId)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
          // Inspirational quote card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Card(
              color: Colors.white70,
              shadowColor: primaryGreen.withOpacity(0.6),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: primaryGreen, width: 1.8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  randomQuote,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: primaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Today's score display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  color: primaryGreen,
                  size: 40,
                ),
                const SizedBox(width: 12),
                const Text(
                  "Today's Score:",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                loadingScore
                    ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: primaryGreen,
                      ),
                    )
                    : Text(
                      '$userScore',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
              ],
            ),
          ),

          // Submit a Lie button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 6,
                shadowColor: primaryGreen.withOpacity(0.7),
              ),
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Please login")));
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubmitLiePage()),
                );
              },
              child: const Text(
                "Submit a Lie",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Go to Lie Chat button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen.withOpacity(0.85),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 5,
                shadowColor: primaryGreen.withOpacity(0.6),
              ),
              onPressed: () {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Please login")));
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LieChatUsersPage(currentUserId: user.id),
                  ),
                );
              },
              child: const Text(
                "Go to Lie Chat",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Leaderboard title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Today's Leaderboard - Top 10",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          // Leaderboard list
          Padding(
            padding: const EdgeInsets.all(10),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: primaryGreen.withOpacity(0.9),
              child:
                  loadingLeaderboard
                      ? Padding(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        ),
                      )
                      : leaderboard.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            "No leaderboard data.",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      )
                      : ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: leaderboard.length,
                        separatorBuilder:
                            (_, __) => Divider(
                              height: 1,
                              color: primaryGreen.withOpacity(0.3),
                            ),
                        itemBuilder: (_, idx) {
                          final row = leaderboard[idx];
                          final profile = row['profiles'] ?? {};
                          final avatar = row['profiles']?['avatar_url'] ?? '';
                          final country = row['country'] ?? 'Unknown';

                          return ListTile(
                            leading:
                                avatar.isNotEmpty
                                    ? CircleAvatar(
                                      backgroundImage: NetworkImage(avatar),
                                      radius: 24,
                                    )
                                    : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: primaryGreen.withOpacity(
                                        0.4,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                            title: Text(
                              row['username'] ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            subtitle: Text(
                              country,
                              style: TextStyle(
                                color: primaryGreen.withOpacity(0.7),
                              ),
                            ),
                            trailing: Text(
                              '${row['score']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: primaryGreen,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                          );
                        },
                      ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({required this.url, super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url);
    _controller.initialize().then((_) {
      setState(() {
        initialized = true;
        _controller.setLooping(true);
        _controller.play();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_controller.value.isInitialized) return;

    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: _togglePlayPause,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
