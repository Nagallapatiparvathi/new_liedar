import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'dart:io' show File, Platform;
import 'package:path_provider/path_provider.dart';

const Color kLieDarBg = Color(0xFFD8E4BC);
const Color kAccent = Color(0xFF00A86B);

class Badge {
  final String name;
  final String description;
  final IconData icon;
  final bool unlocked;

  Badge({
    required this.name,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}

class StreakBadgesPage extends StatefulWidget {
  const StreakBadgesPage({super.key});

  @override
  _StreakBadgesPageState createState() => _StreakBadgesPageState();
}

class _StreakBadgesPageState extends State<StreakBadgesPage> {
  int _streak = 0;
  List<DateTime> _lieDates = [];
  List<Badge> _badges = [];
  bool _isLoading = true;
  String? userDisplayName;

  dynamic getCurrentUserId() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return user.id;
  }

  Future<String> _getUserDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return "User";
    final res =
        await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();
    return res?['username']?.toString() ?? "User";
  }

  List<DateTime> _getUserDates(List<dynamic> lies) {
    return lies
        .map((lie) => DateTime.tryParse(lie['created_at'] ?? ''))
        .whereType<DateTime>()
        .toList();
  }

  int _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    dates.sort((a, b) => b.compareTo(a));
    DateTime today = DateTime.now();
    int streak = 0;
    Set<String> usedDays = {};
    for (int i = 0; i < dates.length; i++) {
      DateTime day = DateTime(dates[i].year, dates[i].month, dates[i].day);
      String dayKey = "${day.year}-${day.month}-${day.day}";
      if (usedDays.contains(dayKey)) continue;
      usedDays.add(dayKey);
      DateTime expectedDay = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: streak));
      if (day == expectedDay) {
        streak++;
      } else if (day.isBefore(expectedDay)) {
        break;
      }
    }
    return streak;
  }

  List<Badge> _getBadgeStates(
    int streak,
    int totalLies,
    List<DateTime> dates,
    List<dynamic> response,
  ) {
    final regions = response.map((lie) => lie['region']).toSet();
    final hasAnonymous = response.any((lie) => lie['is_anonymous'] == true);

    List<Badge> baseBadges = [
      Badge(
        name: "Novice Liar",
        description: "Submitted first lie!",
        icon: Icons.emoji_emotions,
        unlocked: totalLies >= 1,
      ),
      Badge(
        name: "10 Lies Club",
        description: "Submitted 10 lies.",
        icon: Icons.star,
        unlocked: totalLies >= 10,
      ),
      Badge(
        name: "One Week Streak",
        description: "7-day streak!",
        icon: Icons.bolt,
        unlocked: streak >= 7,
      ),
      Badge(
        name: "Two Week Warrior",
        description: "14-day streak!",
        icon: Icons.favorite,
        unlocked: streak >= 14,
      ),
      Badge(
        name: "Monthly Maverick",
        description: "30-day streak!",
        icon: Icons.cake,
        unlocked: streak >= 30,
      ),
      Badge(
        name: "Early Bird",
        description: "Posted a lie before 8AM.",
        icon: Icons.wb_sunny,
        unlocked: dates.any((dt) => dt.hour < 8),
      ),
      Badge(
        name: "Night Owl",
        description: "Posted a lie after 10PM.",
        icon: Icons.nights_stay,
        unlocked: dates.any((dt) => dt.hour >= 22),
      ),
      Badge(
        name: "No Misses",
        description: "Posted every day for a week (no gap).",
        icon: Icons.thumb_up,
        unlocked: streak >= 7 && dates.length >= 7,
      ),
      Badge(
        name: "First Monday Lie",
        description: "Posted on a Monday.",
        icon: Icons.calendar_today,
        unlocked: dates.any((dt) => dt.weekday == DateTime.monday),
      ),
      Badge(
        name: "First Friday Lie",
        description: "Posted on a Friday.",
        icon: Icons.calendar_today,
        unlocked: dates.any((dt) => dt.weekday == DateTime.friday),
      ),
      Badge(
        name: "Consistency King",
        description: "Posted 5 days in a row.",
        icon: Icons.repeat,
        unlocked: streak >= 5,
      ),
      Badge(
        name: "Explorer",
        description: "Posted lies from 3 different regions.",
        icon: Icons.explore,
        unlocked: regions.length >= 3,
      ),
      Badge(
        name: "Social Sharer",
        description: "Shared a badge.",
        icon: Icons.share,
        unlocked: false,
      ),
      Badge(
        name: "First Emoji",
        description: "Used an emoji in a lie.",
        icon: Icons.emoji_events,
        unlocked: true,
      ),
      Badge(
        name: "Early Adopter",
        description: "Joined app in first month.",
        icon: Icons.new_releases,
        unlocked:
            dates.isNotEmpty &&
            dates.first.difference(DateTime.now()).inDays > -30,
      ),
      Badge(
        name: "Weekend Warrior",
        description: "Posted on both Sat and Sun.",
        icon: Icons.beach_access,
        unlocked:
            dates.any((dt) => dt.weekday == DateTime.saturday) &&
            dates.any((dt) => dt.weekday == DateTime.sunday),
      ),
      Badge(
        name: "100 Lies Legend",
        description: "Submitted 100 lies.",
        icon: Icons.verified,
        unlocked: totalLies >= 100,
      ),
      Badge(
        name: "First Anonymous Lie",
        description: "Posted at least one anonymous lie.",
        icon: Icons.visibility_off,
        unlocked: hasAnonymous,
      ),
      Badge(
        name: "Missed a Day",
        description: "Missed a day (streak reset).",
        icon: Icons.error,
        unlocked: streak == 0 && dates.isNotEmpty,
      ),
    ];

    int unlockedCount = baseBadges.where((b) => b.unlocked).length;
    baseBadges.add(
      Badge(
        name: "Badge Master",
        description: "Unlocked 10 badges!",
        icon: Icons.emoji_events,
        unlocked: unlockedCount >= 10,
      ),
    );
    return baseBadges;
  }

  Future<void> _fetchUserLies() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('lies')
          .select()
          .eq('user_id', userId);

      List<DateTime> dates = _getUserDates(response ?? []);
      int streak = _calculateStreak(dates);
      int totalLies = dates.length;
      List<Badge> badges = _getBadgeStates(
        streak,
        totalLies,
        dates,
        response ?? [],
      );
      final displayName = await _getUserDisplayName();

      setState(() {
        _streak = streak;
        _lieDates = dates;
        _badges = badges;
        _isLoading = false;
        userDisplayName = displayName;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load your lies or badges.")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserLies();
  }

  // ---- Streak Share Card ----
  Widget buildStreakShareCard(int streak, String? displayName) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: kAccent.withOpacity(0.14),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (displayName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      color: kAccent,
                      letterSpacing: 1.05,
                    ),
                  ),
                ),
              Icon(Icons.whatshot, color: Colors.orange, size: 54),
              SizedBox(height: 12),
              Text(
                "Current Streak",
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: kAccent,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "$streak days",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 15,
            right: 14,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/logo.png", width: 30, height: 30),
                const SizedBox(width: 8),
                Text(
                  "LieDar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kAccent,
                    fontFamily: "Montserrat",
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareStreak() async {
    if (kIsWeb) {
      await Share.share(
        "${userDisplayName ?? "User"}'s current streak on LieDar: $_streak days! 🔥\nShared via LieDar",
      );
      return;
    }
    OverlayState overlay = Overlay.of(context);
    OverlayEntry? entry;
    final shareKey = GlobalKey();

    entry = OverlayEntry(
      builder:
          (_) => Center(
            child: Material(
              color: Colors.black12,
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: shareKey,
                child: buildStreakShareCard(_streak, userDisplayName),
              ),
            ),
          ),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      if (shareKey.currentContext == null) return;
      RenderRepaintBoundary boundary =
          shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/streak_${DateTime.now().millisecondsSinceEpoch}.png';
      final imgFile = await File(filePath).writeAsBytes(pngBytes);
      await Share.shareXFiles([
        XFile(imgFile.path),
      ], text: 'My streak on LieDar!');
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not share streak image.")));
    } finally {
      entry?.remove();
    }
  }

  Widget buildBadgeShareCard(Badge badge) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: kAccent.withOpacity(0.14),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userDisplayName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    userDisplayName!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      color: kAccent,
                      letterSpacing: 1.02,
                    ),
                  ),
                ),
              Material(
                elevation: 10,
                shape: CircleBorder(),
                shadowColor: kAccent.withOpacity(0.17),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: badge.unlocked ? kAccent : Colors.grey[300],
                  child: Icon(
                    badge.icon,
                    size: 68,
                    color: badge.unlocked ? Colors.white : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                badge.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: kAccent,
                  letterSpacing: 1.05,
                  fontFamily: "Montserrat",
                ),
              ),
              const SizedBox(height: 13),
              Text(
                badge.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17),
              ),
            ],
          ),
          Positioned(
            bottom: 15,
            right: 15,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset("assets/logo.png", width: 30, height: 30),
                const SizedBox(width: 8),
                Text(
                  "LieDar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: kAccent,
                    fontFamily: "Montserrat",
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareBadge(Badge badge) async {
    if (kIsWeb) {
      final shareText = '''
${userDisplayName ?? "User"} unlocked a badge on LieDar!

🏅 ${badge.name}
${badge.description}

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
              color: Colors.black12,
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: shareKey,
                child: buildBadgeShareCard(badge),
              ),
            ),
          ),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 120));

    try {
      if (shareKey.currentContext == null) return;
      RenderRepaintBoundary boundary =
          shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.57);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/badge_${badge.name.replaceAll(" ", "")}${DateTime.now().millisecondsSinceEpoch}.png';
      final imgFile = await File(filePath).writeAsBytes(pngBytes);
      await Share.shareXFiles([
        XFile(imgFile.path),
      ], text: 'See my badge on LieDar!');
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not share badge image.")));
    } finally {
      entry?.remove();
    }
  }

  void _showBadgeInfo(Badge badge) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(badge.name, style: TextStyle(color: kAccent)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badge.description, textAlign: TextAlign.center),
                const SizedBox(height: 23),
                ElevatedButton.icon(
                  icon: Icon(Icons.share, color: kAccent),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent.withOpacity(0.12),
                  ),
                  label: const Text(
                    "Share as Post",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _shareBadge(badge);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close", style: TextStyle(color: kAccent)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = getCurrentUserId();
    if (userId == null) {
      return Scaffold(
        backgroundColor: kLieDarBg,
        appBar: AppBar(
          title: Text("Streak & Badges"),
          backgroundColor: kAccent,
        ),
        body: Center(
          child: Text("You must be logged in to view your streaks and badges."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kLieDarBg,
      appBar: AppBar(title: Text("Streak & Badges"), backgroundColor: kAccent),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: kAccent))
              : Padding(
                padding: const EdgeInsets.all(17.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Card(
                      elevation: 7,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white,
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 25,
                          horizontal: 25,
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Current Streak",
                              style: TextStyle(
                                fontSize: 19,
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold,
                                color: kAccent,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.whatshot,
                                  color: Colors.orange,
                                  size: 32,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '$_streak',
                                  style: TextStyle(
                                    fontSize: 39,
                                    fontWeight: FontWeight.w900,
                                    color: kAccent,
                                    letterSpacing: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _streak == 1 ? "day" : "days",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            if (_streak > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "🔥 Keep your streak going!",
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            SizedBox(height: 13),
                            ElevatedButton.icon(
                              icon: Icon(Icons.share, color: kAccent),
                              label: Text(
                                "Share Streak",
                                style: TextStyle(
                                  color: kAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kAccent.withOpacity(0.11),
                              ),
                              onPressed: _shareStreak,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Your Badges",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: kAccent,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.emoji_events, color: kAccent, size: 24),
                      ],
                    ),
                    SizedBox(height: 7),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(top: 6, bottom: 12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.81,
                        ),
                        itemCount: _badges.length,
                        itemBuilder: (context, index) {
                          final badge = _badges[index];
                          final isUnlocked = badge.unlocked;

                          return GestureDetector(
                            onTap: () => _showBadgeInfo(badge),
                            child: Card(
                              color:
                                  isUnlocked
                                      ? kAccent.withOpacity(0.15)
                                      : Colors.white,
                              elevation: isUnlocked ? 9 : 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                  color:
                                      isUnlocked ? kAccent : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 7,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 29,
                                      backgroundColor:
                                          isUnlocked
                                              ? kAccent
                                              : Colors.grey[300],
                                      child: Icon(
                                        badge.icon,
                                        size: 36,
                                        color:
                                            isUnlocked
                                                ? Colors.white
                                                : Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      badge.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.4,
                                        fontWeight:
                                            isUnlocked
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        color:
                                            isUnlocked
                                                ? kAccent
                                                : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
