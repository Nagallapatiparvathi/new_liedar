import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'userprofilepage.dart'; // adjust import if needed

const Color kLieDarBg = Color(0xFFD8E4BC);
const Color kAccent = Color(0xFF00A000);

const reactionsList = [
  {'emoji': '🤣', 'type': 'funny'},
  {'emoji': '😱', 'type': 'shocked'},
  {'emoji': '😭', 'type': 'sad'},
  {'emoji': '😡', 'type': 'angry'},
  {'emoji': '🤯', 'type': 'mindblown'},
  {'emoji': '❤', 'type': 'love'},
];

class ExploreLiesPage extends StatefulWidget {
  const ExploreLiesPage({super.key});
  @override
  State<ExploreLiesPage> createState() => _ExploreLiesPageState();
}

class _ExploreLiesPageState extends State<ExploreLiesPage> {
  List lies = [];
  List<Map<String, dynamic>> users = [];
  String userQuery = '';
  bool _isLoading = true;
  bool _isSearchingUsers = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchLies();
  }

  Future<void> _fetchLies() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('lies')
          .select(
            'id, lie_text, region, category, is_anonymous, user_id, image_url, profiles(username,avatar_url)',
          )
          .order('created_at', ascending: false);
      setState(() {
        lies = res as List;
        _isLoading = false;
        _errorMsg = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "Error loading lies: $e";
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMsg!)));
      });
    }
  }

  Future<void> _searchUsers(String input) async {
    setState(() {
      userQuery = input;
      _isSearchingUsers = true;
    });
    if (input.trim().isEmpty) {
      setState(() {
        users = [];
        _isSearchingUsers = false;
      });
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, username, bio, avatar_url')
          .ilike('username', '%$input%');
      setState(() {
        users = List<Map<String, dynamic>>.from(res);
        _isSearchingUsers = false;
      });
    } catch (e) {
      setState(() {
        users = [];
        _isSearchingUsers = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User search error: $e')));
    }
  }

  Future<String?> _getReactionForUser(String lieId) async {
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

  Future<int> _getReactionCount(String lieId, String reactionType) async {
    final res = await Supabase.instance.client
        .from('reactions')
        .select('id')
        .eq('lie_id', lieId)
        .eq('reaction_type', reactionType);
    return (res as List).length;
  }

  Future<void> _reactToLie(String lieId, String reactionType) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Remove old reaction
    await Supabase.instance.client
        .from('reactions')
        .delete()
        .eq('lie_id', lieId)
        .eq('user_id', user.id);

    final String username =
        (user.userMetadata != null && user.userMetadata!['username'] != null)
            ? user.userMetadata!['username'] as String
            : '';

    try {
      await Supabase.instance.client.from('reactions').insert({
        'lie_id': lieId,
        'user_id': user.id,
        'reaction_type': reactionType,
        'reactor_username': username,
      });
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Reaction added!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reaction error: $e")));
    }
  }

  Widget _reactionRow(String lieId) {
    return FutureBuilder<String?>(
      future: _getReactionForUser(lieId),
      builder: (context, snapshot) {
        final myReaction = snapshot.data;
        return Wrap(
          spacing: 2,
          runSpacing: 3,
          children:
              reactionsList.map((reaction) {
                final emoji = reaction['emoji']!;
                final type = reaction['type']!;
                final isSelected = myReaction == type;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChoiceChip(
                      label: Text(emoji, style: const TextStyle(fontSize: 16)),
                      selected: isSelected,
                      selectedColor: kAccent.withOpacity(0.25),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 7,
                      ),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide(color: kAccent, width: 1.0),
                      onSelected:
                          isSelected ? null : (_) => _reactToLie(lieId, type),
                    ),
                    const SizedBox(width: 2),
                    FutureBuilder<int>(
                      future: _getReactionCount(lieId, type),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return Text(
                          '$count',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kAccent,
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

  Widget _userSearchSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              labelText: "Search users by username",
              labelStyle: const TextStyle(
                color: kAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              prefixIcon: const Icon(Icons.search, color: kAccent),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: _searchUsers,
          ),
        ),
        if (_isSearchingUsers)
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(color: kAccent),
          ),
        if (!_isSearchingUsers && userQuery.isNotEmpty)
          users.isNotEmpty
              ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: kAccent.withAlpha(90), width: 1.1),
                  borderRadius: BorderRadius.circular(13),
                  color: Colors.white.withOpacity(0.92),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (ctx, idx) {
                    final user = users[idx];
                    final String username = user['username'] ?? "";
                    final String? avatarUrl = user['avatar_url'];
                    final String bio = user['bio'] ?? "";
                    return ListTile(
                      leading:
                          avatarUrl != null && avatarUrl.isNotEmpty
                              ? CircleAvatar(
                                backgroundImage: NetworkImage(avatarUrl),
                              )
                              : CircleAvatar(
                                backgroundColor: kAccent,
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : "U",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      title: Text(
                        username,
                        style: const TextStyle(
                          color: kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle:
                          bio.isNotEmpty
                              ? Text(
                                bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                              : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => UserProfilePage(
                                  userId: user['id'].toString(),
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  "No users found.",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
      ],
    );
  }

  Future<void> _shareLie(Map lie, String lieId) async {
    final bool isAnonymous = (lie['is_anonymous'] ?? false);
    final profile = lie['profiles'];
    final String userDisplay =
        isAnonymous
            ? "Anonymous"
            : (profile != null &&
                profile['username'] != null &&
                profile['username'].toString().isNotEmpty)
            ? profile['username']
            : '';
    final String region = (lie['region'] ?? '').toString();
    final String lieText = (lie['lie_text'] ?? '').toString();
    final String category = (lie['category'] ?? 'No Category').toString();

    List<int> reactionCounts = [];
    for (final reaction in reactionsList) {
      final count = await _getReactionCount(lieId, reaction['type']!);
      reactionCounts.add(count);
    }

    if (kIsWeb) {
      String emojiCounts =
          reactionCounts
              .asMap()
              .entries
              .map(
                (entry) =>
                    '${reactionsList[entry.key]['emoji']}${entry.value > 0 ? ' ${entry.value}' : ''}  ',
              )
              .join();
      final shareText = '''
$userDisplay (${region.isNotEmpty ? region : "No Country"})
Category: $category




"$lieText"




$emojiCounts




Shared via LieDar
''';
      await Share.share(shareText);
      return;
    }

    OverlayState? overlay = Overlay.of(context);
    OverlayEntry? entry;

    final GlobalKey key = GlobalKey();

    entry = OverlayEntry(
      builder:
          (_) => Center(
            child: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: key,
                child: buildShareCard(lie, reactionCounts),
              ),
            ),
          ),
    );

    overlay?.insert(entry);

    await Future.delayed(const Duration(milliseconds: 110));

    try {
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.4);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final imgFile = File(
        '${directory.path}/lie_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await imgFile.writeAsBytes(pngBytes);
      await Share.shareXFiles([
        XFile(imgFile.path),
      ], text: 'Check out this LieDub post!');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not share.")));
    } finally {
      entry.remove();
    }
  }

  Widget buildShareCard(Map lie, List<int> reactionCounts) {
    final bool isAnonymous = (lie['is_anonymous'] ?? false);
    final profile = lie['profiles'];
    final String userDisplay =
        isAnonymous
            ? "Anonymous"
            : (profile != null &&
                profile['username'] != null &&
                profile['username'].toString().isNotEmpty)
            ? profile['username']
            : '';
    final String avatarUrl =
        !isAnonymous && profile != null && profile['avatar_url'] != null
            ? profile['avatar_url'].toString()
            : '';
    final String region = (lie['region'] ?? '').toString();
    final String lieText = (lie['lie_text'] ?? '').toString();
    final String category = (lie['category'] ?? 'No Category').toString();
    final String? imageUrl = lie['image_url'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kAccent.withOpacity(0.10),
            blurRadius: 7,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      width: 350,
      constraints: const BoxConstraints(maxWidth: 400),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isAnonymous ? kAccent : Colors.grey,
                      backgroundImage:
                          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child:
                          isAnonymous
                              ? const Icon(
                                Icons.privacy_tip,
                                size: 22,
                                color: Colors.white,
                              )
                              : avatarUrl.isEmpty
                              ? Text(
                                userDisplay.isNotEmpty ? userDisplay[0] : "U",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: kAccent,
                                ),
                              )
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                          ),
                          if (region.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: kAccent,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  region,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kAccent,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  lieText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.35,
                  ),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                          ),
                        );
                      },
                      errorBuilder:
                          (context, error, stackTrace) =>
                              const Center(child: Text('Failed to load image')),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.folder_special, color: Colors.deepPurple),
                    const SizedBox(width: 4),
                    Text(
                      category,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                        fontSize: 13.7,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  children: List.generate(reactionsList.length, (index) {
                    final emoji = reactionsList[index]['emoji']!;
                    final count = reactionCounts[index];
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 4),
                        Text(
                          count.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kAccent,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lieTile(Map lie) {
    final bool isAnonymous = (lie['is_anonymous'] ?? false);
    final profile = lie['profiles'];
    final String userDisplay =
        isAnonymous
            ? "Anonymous"
            : (profile != null &&
                profile['username'] != null &&
                profile['username'].toString().isNotEmpty)
            ? profile['username']
            : '';
    final String avatarUrl =
        !isAnonymous && profile != null && profile['avatar_url'] != null
            ? profile['avatar_url'].toString()
            : '';
    final String? imageUrl = lie['image_url'];
    final String lieId = lie['id'].toString();
    final String region = (lie['region'] ?? '').toString();
    final String lieText = (lie['lie_text'] ?? '').toString();
    final String category = (lie['category'] ?? 'No Category').toString();

    return Card(
      color: Colors.white,
      elevation: 7,
      shadowColor: kAccent.withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isAnonymous ? kAccent : Colors.grey,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child:
                      isAnonymous
                          ? const Icon(
                            Icons.privacy_tip,
                            size: 22,
                            color: Colors.white,
                          )
                          : avatarUrl.isEmpty
                          ? Text(
                            userDisplay.isNotEmpty ? userDisplay[0] : "U",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: kAccent,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                      ),
                      if (region.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: kAccent,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              region,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kAccent,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lieText,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: 1.35,
              ),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value:
                            progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                      ),
                    );
                  },
                  errorBuilder:
                      (context, error, stackTrace) =>
                          const Center(child: Text('Failed to load image')),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.folder_special, color: Colors.deepPurple),
                const SizedBox(width: 4),
                Text(
                  category,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600,
                    fontSize: 13.7,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _reactionRow(lieId),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.share,
                  color: Colors.deepPurple,
                  size: 20,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent.withOpacity(0.12),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  foregroundColor: Colors.deepPurple,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                onPressed: () => _shareLie(lie, lieId),
                label: const Text(
                  "Share",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLieDarBg,
      appBar: AppBar(
        title: const Text(
          'Explore Lies',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kAccent,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _userSearchSection(),
            Expanded(
              child:
                  _isLoading
                      ? Center(child: CircularProgressIndicator(color: kAccent))
                      : _errorMsg != null
                      ? Center(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                      : lies.isEmpty
                      ? Center(
                        child: Text(
                          "No lies found.",
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16, top: 7),
                        itemCount: lies.length,
                        itemBuilder: (ctx, idx) => _lieTile(lies[idx]),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
