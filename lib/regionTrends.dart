import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show File, Platform;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'userProfilePage.dart';
import 'package:timeago/timeago.dart' as timeago;

const Color kLieDarBg = Color(0xFFD8E4BC);
const Color kAccent = Color(0xFF00A86B);
const Color kDeepPurple = Colors.deepPurple;

final List<Map<String, String>> countryList = [
  {"name": "India"},
  {"name": "United States"},
  {"name": "United Kingdom"},
  {"name": "Australia"},
  {"name": "Canada"},
  {"name": "Germany"},
  {"name": "France"},
  {"name": "Brazil"},
  {"name": "Japan"},
  {"name": "China"},
  {"name": "South Africa"},
  {"name": "Mexico"},
  {"name": "Others"},
];

final List<String> categories = [
  'All',
  'Politics',
  'Entertainment',
  'Sports',
  'Technology',
  'Health',
  'Personal',
  'Others',
];

const reactionsList = [
  {'emoji': '🤣', 'type': 'funny'},
  {'emoji': '😱', 'type': 'shocked'},
  {'emoji': '😭', 'type': 'sad'},
  {'emoji': '😡', 'type': 'angry'},
  {'emoji': '🤯', 'type': 'mindblown'},
  {'emoji': '❤', 'type': 'love'},
];

class RegionalTrendsPage extends StatefulWidget {
  const RegionalTrendsPage({super.key});
  @override
  State<RegionalTrendsPage> createState() => _RegionalTrendsPageState();
}

class _RegionalTrendsPageState extends State<RegionalTrendsPage> {
  List lies = [];
  bool _isLoading = true;
  String? _errorMsg;
  Map<String, String>? _selectedCountry;
  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchRegionalLies();
  }

  Future<void> _fetchRegionalLies() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      lies = [];
    });
    try {
      final res = await Supabase.instance.client
          .from('lies')
          .select(
            'id, lie_text, region, category, created_at, is_anonymous, user_id, image_url, profiles(username, country, avatar_url)',
          )
          .order('created_at', ascending: false);
      setState(() {
        lies = res as List;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = "Error loading trends: $e";
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMsg!)));
      });
    }
  }

  List get filteredLies {
    List filtered = lies;
    if (_selectedCountry != null) {
      final country = _selectedCountry!['name'];
      filtered =
          filtered.where((lie) {
            final String region = (lie['region'] ?? '').toString();
            return region == country;
          }).toList();
    }
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((lie) {
            final String category = (lie['category'] ?? '').toString();
            return category.trim().toLowerCase() ==
                _selectedCategory.trim().toLowerCase();
          }).toList();
    }
    return filtered;
  }

  List get sortedLies {
    List trends = filteredLies;
    trends.sort((a, b) {
      String regA = (a['region'] ?? '').toString();
      String regB = (b['region'] ?? '').toString();
      int byRegion = regA.compareTo(regB);
      if (byRegion != 0) return byRegion;

      DateTime dateA =
          DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      DateTime dateB =
          DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA); // newest first
    });
    return trends;
  }

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
    if (res != null && res['reaction_type'] != null) {
      return res['reaction_type'];
    }
    return null;
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
      ).showSnackBar(const SnackBar(content: Text("Reaction added!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reaction error: $e")));
    }
  }

  Future<int> _getReactionCount(int lieId, String reactionType) async {
    final res = await Supabase.instance.client
        .from('reactions')
        .select('id')
        .eq('lie_id', lieId)
        .eq('reaction_type', reactionType);
    return (res as List).length;
  }

  Widget _reactionRow(int lieId) {
    return FutureBuilder(
      future: _getUserReaction(lieId),
      builder: (context, AsyncSnapshot<String?> snapshot) {
        final myReactionType = snapshot.data;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children:
              reactionsList.map((reaction) {
                final emoji = reaction['emoji']!;
                final type = reaction['type']!;
                final isSelected = myReactionType == type;
                return ChoiceChip(
                  label: Text(emoji, style: const TextStyle(fontSize: 26)),
                  selected: isSelected,
                  selectedColor: kAccent.withOpacity(0.3),
                  backgroundColor: Colors.white,
                  elevation: 1,
                  side: BorderSide(
                    color: isSelected ? kAccent : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  onSelected:
                      isSelected ? null : (_) => _reactToLie(lieId, type),
                );
              }).toList(),
        );
      },
    );
  }

  Widget buildShareCard(Map lie, List<int> reactionCounts, double screenWidth) {
    final bool isAnonymous = (lie['is_anonymous'] ?? false);
    final profile = lie['profiles'];
    final String username =
        isAnonymous
            ? "Anonymous"
            : ((profile != null && profile['username'] != null)
                ? profile['username'].toString()
                : 'Unknown');
    final String userInitial =
        username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final String region = (lie['region'] ?? '').toString();
    final String lieText = (lie['lie_text'] ?? '').toString();
    final String category = (lie['category'] ?? 'No Category').toString();
    final String avatarUrl =
        !isAnonymous && profile != null && profile['avatar_url'] != null
            ? profile['avatar_url'].toString()
            : '';
    final String imageUrl = lie['image_url'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kAccent.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(3, 6),
          ),
        ],
      ),
      width: screenWidth * 0.95,
      constraints: const BoxConstraints(maxWidth: 420),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 54),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isAnonymous ? Colors.blueGrey : kAccent,
                      backgroundImage:
                          (!isAnonymous && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                      child:
                          isAnonymous
                              ? const Icon(
                                Icons.privacy_tip,
                                size: 29,
                                color: Colors.white,
                              )
                              : (avatarUrl.isEmpty
                                  ? Text(
                                    userInitial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 25,
                                      color: Colors.white,
                                    ),
                                  )
                                  : null),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (region.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: kAccent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  region,
                                  style: const TextStyle(
                                    fontSize: 15,
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
                const SizedBox(height: 14),
                Text(
                  "Category: $category",
                  style: const TextStyle(
                    color: kDeepPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lieText.isNotEmpty ? lieText : "No text added.",
                  style: const TextStyle(
                    fontSize: 21,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: FadeInImage.assetNetwork(
                          placeholder: 'assets/placeholder.png',
                          image: imageUrl,
                          fit: BoxFit.cover,
                          imageErrorBuilder:
                              (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: List.generate(
                    reactionsList.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Row(
                        children: [
                          Text(
                            reactionsList[i]['emoji']!,
                            style: const TextStyle(fontSize: 21),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reactionCounts[i]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 11,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/logo.png", width: 28, height: 28),
                const SizedBox(width: 9),
                const Text(
                  "LieDar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    color: kAccent,
                    fontFamily: "Montserrat",
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareTrend(Map lie, int lieId, double screenWidth) async {
    final bool isAnonymous = (lie['is_anonymous'] ?? false);
    final profile = lie['profiles'];
    final String username =
        isAnonymous
            ? "Anonymous"
            : ((profile != null && profile['username'] != null)
                ? profile['username'].toString()
                : 'Unknown');
    final String region = (lie['region'] ?? '').toString();
    final String lieText = (lie['lie_text'] ?? '').toString();
    final String category = (lie['category'] ?? 'No Category').toString();

    List<int> reactionCounts = [];
    for (final reaction in reactionsList) {
      final count = await _getReactionCount(lieId, reaction['type']!);
      reactionCounts.add(count);
    }

    if (kIsWeb) {
      String emojiCounts = '';
      for (int i = 0; i < reactionsList.length; i++) {
        emojiCounts +=
            '${reactionsList[i]['emoji']}${reactionCounts[i] > 0 ? ' ${reactionCounts[i]}' : ''}  ';
      }
      final shareText = '''
$username (${region.isNotEmpty ? region : "No Country"})
Category: $category


"$lieText"


$emojiCounts


Shared via LieDar
''';
      await Share.share(shareText);
      return;
    }

    OverlayState overlay = Overlay.of(context);
    OverlayEntry? entry;

    final shareKey = GlobalKey();

    entry = OverlayEntry(
      builder:
          (_) => Center(
            child: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: shareKey,
                child: buildShareCard(lie, reactionCounts, screenWidth),
              ),
            ),
          ),
    );
    overlay.insert(entry);

    await Future.delayed(const Duration(milliseconds: 110));

    try {
      RenderRepaintBoundary boundary =
          shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.4);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/trend_card_${DateTime.now().millisecondsSinceEpoch}.png';
      final imgFile = await File(filePath).writeAsBytes(pngBytes);
      await Share.shareXFiles([
        XFile(imgFile.path),
      ], text: 'Check out this trend on LieDar!');
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not share post image.")),
      );
    } finally {
      entry?.remove();
    }
  }

  Widget _trendTile(Map lie, double screenWidth) {
    final bool isAnonymous = (lie['is_anonymous'] ?? false);
    final profile = lie['profiles'];
    final String username =
        isAnonymous
            ? "Anonymous"
            : ((profile != null && profile['username'] != null)
                ? profile['username'].toString()
                : 'Unknown');
    final String userInitial =
        username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final String region = (lie['region'] ?? '').toString();
    final String lieText = (lie['lie_text'] ?? '').toString();
    final String category = (lie['category'] ?? 'No Category').toString();
    final int lieId = lie['id'];
    final String avatarUrl =
        !isAnonymous && profile != null && profile['avatar_url'] != null
            ? profile['avatar_url'].toString()
            : '';
    final String imageUrl = lie['image_url'] ?? '';

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: screenWidth * 0.07,
              backgroundColor: isAnonymous ? Colors.blueGrey : kAccent,
              backgroundImage:
                  (!isAnonymous && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
              child:
                  isAnonymous
                      ? const Icon(
                        Icons.privacy_tip,
                        size: 23,
                        color: Colors.white,
                      )
                      : (avatarUrl.isEmpty
                          ? Text(
                            userInitial,
                            style: TextStyle(
                              fontSize: screenWidth * 0.06,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null),
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: screenWidth * 0.042,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: screenWidth * 0.01),
                  Text(
                    region,
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: kAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              _formatTimeAgo(lie['created_at']),
              style: TextStyle(
                fontSize: screenWidth * 0.032,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.03),
        Text(
          "Category: $category",
          style: TextStyle(
            color: kDeepPurple,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.038,
          ),
        ),
        SizedBox(height: screenWidth * 0.025),
        Text(
          lieText.isNotEmpty ? lieText : "No text added.",
          style: TextStyle(
            fontSize: screenWidth * 0.044,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (imageUrl.isNotEmpty) ...[
          SizedBox(height: screenWidth * 0.025),
          SizedBox(
            width: double.infinity,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FadeInImage.assetNetwork(
                  placeholder: 'assets/placeholder.png',
                  image: imageUrl,
                  fit: BoxFit.cover,
                  imageErrorBuilder:
                      (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
        ],
        SizedBox(height: screenWidth * 0.03),
        _reactionRow(lieId),
        SizedBox(height: screenWidth * 0.02),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: Icon(
              Icons.share,
              color: kDeepPurple,
              size: screenWidth * 0.05,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent.withOpacity(0.14),
              elevation: 0,
              padding: EdgeInsets.symmetric(
                vertical: screenWidth * 0.02,
                horizontal: screenWidth * 0.04,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              foregroundColor: kDeepPurple,
              textStyle: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              await _shareTrend(lie, lieId, screenWidth);
            },
            label: const Text(
              "Share",
              style: TextStyle(color: kDeepPurple, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );

    return Card(
      color: Colors.white,
      elevation: 6,
      shadowColor: kAccent.withOpacity(0.19),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.symmetric(
        vertical: screenWidth * 0.02,
        horizontal: screenWidth * 0.03,
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.045),
        child: content,
      ),
    );
  }

  String _formatTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    final DateTime dateTime = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
    return timeago.format(dateTime);
  }

  Widget _categoryChips() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          return ChoiceChip(
            label: Text(
              cat,
              style: TextStyle(
                color: isSelected ? Colors.white : kAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            selected: isSelected,
            backgroundColor: Colors.white,
            selectedColor: kAccent,
            side: BorderSide(
              color: isSelected ? kAccent : Colors.grey.shade400,
            ),
            onSelected: (bool selected) {
              setState(() {
                _selectedCategory = selected ? cat : 'All';
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _fetchRegionalLies();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: kLieDarBg,
      appBar: AppBar(
        title: Text(
          'Regional Trends',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.05,
            fontFamily: 'Montserrat',
          ),
        ),
        backgroundColor: kAccent,
        elevation: 3,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.04,
                  screenWidth * 0.04,
                  screenWidth * 0.04,
                  0,
                ),
                child: DropdownButtonFormField<Map<String, String>>(
                  value: _selectedCountry,
                  isExpanded: true,
                  icon: const Icon(Icons.flag, color: kAccent),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'All Countries',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: kAccent,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    ...countryList.map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Text(
                          country['name']!,
                          style: const TextStyle(
                            color: kAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCountry = v),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    labelText: "Filter by Country",
                    labelStyle: const TextStyle(
                      color: kAccent,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: kAccent, width: 1.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: kAccent, width: 1.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              _categoryChips(),

              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: kAccent),
                        )
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
                        : (sortedLies.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sentiment_dissatisfied,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No lies found${_selectedCountry != null ? ' for ${_selectedCountry!['name']}' : ''} and category ${_selectedCategory != 'All' ? _selectedCategory : ''}.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Try selecting a different filter or pull down to refresh.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.only(
                                bottom: screenWidth * 0.04,
                                top: screenWidth * 0.025,
                              ),
                              itemCount: sortedLies.length,
                              itemBuilder: (context, index) {
                                return _trendTile(
                                  sortedLies[index],
                                  screenWidth,
                                );
                              },
                            )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
