import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'lieVault.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = '';
  bool loading = true;
  int followers = 0;
  int following = 0;
  String? avatarUrl;
  bool avatarUploading = false;
  List<Map> recentLies = [];
  Map<String, int> emojiStats = {
    '🤣': 0,
    '😱': 0,
    '😭': 0,
    '😡': 0,
    '🤯': 0,
    '❤': 0,
  };
  String? errorMsg;

  List<Map<String, dynamic>> _followersList = [];
  List<Map<String, dynamic>> _followingList = [];

  @override
  void initState() {
    super.initState();
    fetchAllProfileInfo();
    fetchEmojiStats();
  }

  Future<void> fetchAllProfileInfo() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'Not signed in';
      final profile =
          await Supabase.instance.client
              .from('profiles')
              .select('username, avatar_url')
              .eq('id', user.id)
              .maybeSingle();
      final followersRes = await Supabase.instance.client
          .from('follows')
          .select('profiles!follows_follower_id_fkey(username,bio)')
          .eq('followed_id', user.id)
          .eq('status', 'accepted');
      final followingRes = await Supabase.instance.client
          .from('follows')
          .select('profiles!follows_followed_id_fkey(username,bio)')
          .eq('follower_id', user.id)
          .eq('status', 'accepted');
      final recentRes = await Supabase.instance.client
          .from('lies')
          .select('lie_text, category, region')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(2);

      setState(() {
        username = profile?['username'] ?? '';
        avatarUrl = profile?['avatar_url'];
        followers = (followersRes as List).length;
        following = (followingRes as List).length;
        recentLies = List<Map>.from(recentRes ?? []);
        _followersList = List<Map<String, dynamic>>.from(
          (followersRes as List).map((e) => e['profiles'] ?? {}),
        );
        _followingList = List<Map<String, dynamic>>.from(
          (followingRes as List).map((e) => e['profiles'] ?? {}),
        );
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMsg = e.toString();
      });
    }
  }

  Future<void> fetchEmojiStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('lies')
          .select('emonji')
          .eq('user_id', user.id);
      final Map<String, int> temp = {
        '🤣': 0,
        '😱': 0,
        '😭': 0,
        '😡': 0,
        '🤯': 0,
        '❤': 0,
      };
      for (final row in data ?? []) {
        final e = row['emonji'];
        if (e != null && temp.containsKey(e)) temp[e] = temp[e]! + 1;
      }
      setState(() {
        emojiStats = temp;
      });
    } catch (_) {}
  }

  String maskLieText(String text) {
    if (text.isEmpty) return "••••••";
    if (text.length == 1) return "•";
    if (text.length == 2) return text[0] + "•";
    return text[0] + '•' * (text.length - 2) + text[text.length - 1];
  }

  void showUserListDialog(
    String title,
    List<Map<String, dynamic>> users,
    String emptyMsg,
  ) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content:
                users.isEmpty
                    ? SizedBox(
                      width: 280,
                      height: 60,
                      child: Center(
                        child: Text(
                          emptyMsg,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                    : SizedBox(
                      width: 320,
                      height: 400,
                      child: ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final user = users[idx];
                          final uName = (user['username'] ?? '').toString();
                          final displayLetter =
                              uName.isNotEmpty ? uName[0].toUpperCase() : '?';
                          return ListTile(
                            leading: CircleAvatar(child: Text(displayLetter)),
                            title: Text(uName),
                            subtitle:
                                user.containsKey('bio') &&
                                        (user['bio'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty
                                    ? Text(
                                      user['bio'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                    : null,
                          );
                        },
                      ),
                    ),
            actions: [
              TextButton(
                child: const Text("Close"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  Future<void> pickAvatarImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (pickedFile == null) return;

    setState(() => avatarUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final extension = pickedFile.name.split('.').last;
      final filepath = '${user!.id}.$extension';
      final bytes = await pickedFile.readAsBytes();

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filepath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filepath);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      await fetchAllProfileInfo();

      setState(() {
        avatarUploading = false;
      });
    } catch (e) {
      setState(() => avatarUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void showEditUsernameDialog() {
    final TextEditingController controller = TextEditingController(
      text: username,
    );
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Username'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'New Username'),
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Update"),
                onPressed: () async {
                  final newUsername = controller.text.trim();
                  if (newUsername.isNotEmpty && newUsername != username) {
                    await updateUsername(newUsername);
                  }
                },
              ),
            ],
          ),
    );
  }

  Future<void> updateUsername(String newUsername) async {
    final user = Supabase.instance.client.auth.currentUser;
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('username', newUsername)
            .neq('id', user!.id)
            .maybeSingle();
    final unique = (res == null);
    if (!unique) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Username has been taken."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await Supabase.instance.client
        .from('profiles')
        .update({'username': newUsername})
        .eq('id', user.id);
    setState(() {
      username = newUsername;
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Username updated!"),
        backgroundColor: Colors.green,
      ),
    );
    await fetchAllProfileInfo();
  }

  @override
  Widget build(BuildContext context) {
    final totalReactions = emojiStats.values.fold<int>(0, (sum, v) => sum + v);
    final avatar =
        avatarUploading
            ? CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple[100],
              child: const CircularProgressIndicator(),
            )
            : avatarUrl != null
            ? CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(avatarUrl!),
            )
            : CircleAvatar(
              radius: 40,
              backgroundColor: Colors.deepPurple,
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 47,
              ),
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await fetchAllProfileInfo();
              await fetchEmojiStats();
            },
            tooltip: "Refresh Profile",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () async {
                  await fetchAllProfileInfo();
                  await fetchEmojiStats();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 440),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (errorMsg != null) ...[
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              errorMsg!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              avatar,
                              Positioned(
                                bottom: 5,
                                right: 4,
                                child: GestureDetector(
                                  onTap: pickAvatarImage,
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.deepPurple,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              username,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: showEditUsernameDialog,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.edit,
                                      size: 17,
                                      color: Colors.deepPurple,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Edit",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.deepPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap:
                                  () => showUserListDialog(
                                    "Followers",
                                    _followersList,
                                    "No followers yet.",
                                  ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$followers',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        fontSize: 17,
                                      ),
                                    ),
                                    const Text(
                                      "Followers",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap:
                                  () => showUserListDialog(
                                    "Following",
                                    _followingList,
                                    "Not following anyone.",
                                  ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber[50],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '$following',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[700],
                                        fontSize: 17,
                                      ),
                                    ),
                                    const Text(
                                      "Following",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Recent Lies",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...recentLies.map(
                          (lie) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  maskLieText(lie['lie_text'] ?? ""),
                                  style: const TextStyle(
                                    letterSpacing: 1,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      lie['category'] ?? "-",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const Text(" · "),
                                    Text(
                                      lie['region'] ?? "-",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.teal[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.lock),
                            label: const Text("View your LieVault"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              minimumSize: const Size(180, 45),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LieVaultPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Your Lie Reactions",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 210,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            child: BarChart(
                              BarChartData(
                                barGroups:
                                    emojiStats.entries
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                          final i = entry.key;
                                          final emoji = entry.value.key;
                                          final count = entry.value.value;
                                          return BarChartGroupData(
                                            x: i,
                                            barRods: [
                                              BarChartRodData(
                                                toY: count.toDouble(),
                                                color: Colors.blueAccent,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                width: 18,
                                              ),
                                            ],
                                          );
                                        })
                                        .toList(),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 62,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        final keys = emojiStats.keys.toList();
                                        if (idx < 0 || idx >= keys.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final emoji = keys[idx];
                                        final total = emojiStats.values
                                            .fold<int>(0, (sum, v) => sum + v);
                                        final count = emojiStats[emoji] ?? 0;
                                        final percent =
                                            total > 0
                                                ? ((count / total) * 100)
                                                    .toStringAsFixed(1)
                                                : '0.0';
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              emoji,
                                              style: const TextStyle(
                                                fontSize: 21,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              '$percent%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
