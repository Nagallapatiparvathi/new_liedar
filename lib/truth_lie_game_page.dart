import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kLieDarBg = Color(0xFFD8E4BC);
const Color kAccent = Color(0xFF00A86B);

class TruthLieGamePage extends StatefulWidget {
  final VoidCallback? onScoreUpdated;
  const TruthLieGamePage({this.onScoreUpdated, Key? key}) : super(key: key);

  @override
  State<TruthLieGamePage> createState() => _TruthLieGamePageState();
}

class _TruthLieGamePageState extends State<TruthLieGamePage> {
  bool loading = true;
  bool hasPlayedToday = false;
  int userScore = 0;
  String? errorMsg;
  int earnedScore = 0;
  bool gameSubmitted = false;
  String? selectedCountry;

  final List<String> countryList = [
    "India",
    "United States",
    "United Kingdom",
    "Australia",
    "Canada",
    "Germany",
    "France",
    "Brazil",
    "Japan",
    "China",
    "South Africa",
    "Mexico",
    "Others",
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'lie_text': 'The Great Wall of China is visible from space.',
      'correct_answer': 'lie',
    },
    {'lie_text': 'Sharks are mammals.', 'correct_answer': 'lie'},
    {
      'lie_text': 'Venus is the hottest planet in our solar system.',
      'correct_answer': 'truth',
    },
    {
      'lie_text': 'Lightning never strikes the same place twice.',
      'correct_answer': 'lie',
    },
    {
      'lie_text': 'Goldfish have a memory span of three seconds.',
      'correct_answer': 'lie',
    },
    {'lie_text': 'Bananas grow on trees.', 'correct_answer': 'lie'},
    {
      'lie_text': 'The capital of Australia is Sydney.',
      'correct_answer': 'lie',
    },
    {'lie_text': 'Humans and dinosaurs coexisted.', 'correct_answer': 'lie'},
    {'lie_text': 'An octopus has three hearts.', 'correct_answer': 'truth'},
    {'lie_text': 'Honey never spoils.', 'correct_answer': 'truth'},
    {
      'lie_text':
          'There are more stars in the universe than grains of sand on Earth.',
      'correct_answer': 'truth',
    },
    {
      'lie_text': 'Bulls get angry when they see the color red.',
      'correct_answer': 'lie',
    },
    {
      'lie_text': 'Mount Everest is the closest point on Earth to the Moon.',
      'correct_answer': 'lie',
    },
    {
      'lie_text': 'Adult humans have fewer bones than babies.',
      'correct_answer': 'truth',
    },
    {
      'lie_text': 'Dolphins sleep with one eye open.',
      'correct_answer': 'truth',
    },
  ];

  List<bool?> answers = [];
  int currentIdx = 0;
  bool countryPromptShown = false;

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  Future<void> _loadGameState() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          loading = false;
          hasPlayedToday = true;
        });
        return;
      }
      final now = DateTime.now();
      final todayStr =
          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final rows = await Supabase.instance.client
          .from('leaderboard_scores')
          .select('score, country, played_at')
          .eq('user_id', user.id)
          .eq('played_at', todayStr);

      final bool playedToday = rows is List && rows.isNotEmpty;
      if (playedToday) {
        setState(() {
          loading = false;
          hasPlayedToday = true;
          userScore = rows[0]['score'] ?? 0;
          selectedCountry = rows[0]['country'];
        });
        return;
      }

      // Prompt country selection ONLY inside this game page
      if (selectedCountry == null && !countryPromptShown) {
        Future.delayed(
          const Duration(milliseconds: 100),
          () => showCountryDialog(),
        );
        countryPromptShown = true;
        setState(() {
          loading = false;
        });
        return;
      }

      questions.shuffle();
      setState(() {
        answers = List.filled(questions.length, null);
        loading = false;
        hasPlayedToday = false;
        currentIdx = 0;
        earnedScore = 0;
        gameSubmitted = false;
        if (questions.isEmpty) {
          errorMsg = "No questions available in the app.";
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMsg = "Game load failed: $e";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg ?? "Unknown error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showCountryDialog() async {
    String dropdownCountry = countryList.first;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text("Select your country for leaderboard"),
            content: DropdownButton<String>(
              isExpanded: true,
              value: dropdownCountry,
              items:
                  countryList
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (val) {
                if (val != null) {
                  dropdownCountry = val;
                  setState(() {});
                }
              },
            ),
            actions: [
              TextButton(
                child: Text(
                  "OK",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    selectedCountry = dropdownCountry;
                  });
                  Navigator.pop(context);
                  _loadGameState();
                },
              ),
            ],
          ),
    );
  }

  void _recordAnswer(bool isTruth) {
    setState(() {
      answers[currentIdx] = isTruth;
      if (currentIdx < questions.length - 1) {
        currentIdx += 1;
      }
    });
  }

  bool get allAnswered =>
      answers.where((a) => a == null).isEmpty && questions.isNotEmpty;

  Future<void> _submitGame() async {
    if (gameSubmitted) return;
    setState(() {
      gameSubmitted = true;
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    int score = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = answers[i];
      if (userAns == null) continue;
      bool answerIsTruth =
          (q['correct_answer'].toString().trim().toLowerCase() == 'truth');
      if (userAns == answerIsTruth) {
        score += 1;
      }
    }
    earnedScore = score;
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      final profile =
          await Supabase.instance.client
              .from('profiles')
              .select('username')
              .eq('id', user.id)
              .maybeSingle();
      final username = profile?['username'];

      await Supabase.instance.client.from('leaderboard_scores').upsert({
        'user_id': user.id,
        'username': username,
        'score': score,
        'country': selectedCountry,
        'played_at': todayStr,
      }, onConflict: 'user_id,played_at');

      setState(() {
        hasPlayedToday = true;
        userScore = score;
        loading = false;
      });

      if (widget.onScoreUpdated != null) widget.onScoreUpdated!();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Game complete! You scored $earnedScore/${questions.length}.",
          ),
          backgroundColor: kAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => gameSubmitted = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error submitting score: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: kLieDarBg,
        appBar: AppBar(title: Text("Truth/Lie Game"), backgroundColor: kAccent),
        body: Center(child: CircularProgressIndicator(color: kAccent)),
      );
    }
    if (errorMsg != null) {
      return Scaffold(
        backgroundColor: kLieDarBg,
        appBar: AppBar(title: Text("Truth/Lie Game"), backgroundColor: kAccent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              errorMsg!,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (!loading && hasPlayedToday) {
      return Scaffold(
        backgroundColor: kLieDarBg,
        appBar: AppBar(title: Text("Truth/Lie Game"), backgroundColor: kAccent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: kAccent, size: 62),
                    SizedBox(height: 14),
                    Text(
                      "Congratulations, you already completed the game!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: kAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 15),
                    Text(
                      "Come back again tomorrow.",
                      style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                    ),
                    SizedBox(height: 18),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "Your total score: ",
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                          TextSpan(
                            text: "$userScore",
                            style: TextStyle(
                              fontSize: 23,
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    if (selectedCountry != null)
                      Text(
                        "Today's selected country: $selectedCountry",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kLieDarBg,
      appBar: AppBar(title: Text("Truth/Lie Game"), backgroundColor: kAccent),
      body: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Center(
          child:
              questions.isEmpty
                  ? Text(
                    "No questions available in the app.",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!allAnswered)
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 32, 12, 26),
                            child: Column(
                              children: [
                                Text(
                                  "Question ${currentIdx + 1}/${questions.length}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: kAccent,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    color: kAccent.withOpacity(0.10),
                                  ),
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                    questions[currentIdx]['lie_text'] ?? '',
                                    style: TextStyle(
                                      fontSize: 21,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: 23),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed:
                                          allAnswered
                                              ? null
                                              : () => _recordAnswer(true),
                                      icon: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        "Truth",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kAccent,
                                        minimumSize: Size(122, 47),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                        elevation: 5,
                                      ),
                                    ),
                                    SizedBox(width: 26),
                                    ElevatedButton.icon(
                                      onPressed:
                                          allAnswered
                                              ? null
                                              : () => _recordAnswer(false),
                                      icon: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        "Lie",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        minimumSize: Size(122, 47),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                        elevation: 5,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 25),
                                LinearProgressIndicator(
                                  value:
                                      (currentIdx + 1) /
                                      (questions.length > 0
                                          ? questions.length
                                          : 1),
                                  minHeight: 7,
                                  color: kAccent,
                                  backgroundColor: kAccent.withAlpha(60),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (allAnswered)
                        Expanded(
                          child: Center(
                            child: Card(
                              color: Colors.white,
                              elevation: 9,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 32,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      color: Colors.deepPurple,
                                      size: 58,
                                    ),
                                    SizedBox(height: 13),
                                    Text(
                                      "Review your answers?",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: kAccent,
                                      ),
                                    ),
                                    SizedBox(height: 19),
                                    OutlinedButton.icon(
                                      icon: Icon(Icons.check, color: kAccent),
                                      label: Text("Submit Game"),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: kAccent,
                                        side: BorderSide(
                                          color: kAccent,
                                          width: 2,
                                        ),
                                        minimumSize: Size(148, 54),
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            13,
                                          ),
                                        ),
                                      ),
                                      onPressed:
                                          gameSubmitted ? null : _submitGame,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
        ),
      ),
    );
  }
}
