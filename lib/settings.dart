import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? inAppNotificationsEnabled;
  bool? popupNotificationsEnabled;
  bool? chatNotificationsEnabled; // Added state var for chat notifications
  TimeOfDay? reminderTime;
  bool? isPrivate;
  bool isLoading = true;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initTimezone();
    _initNotifications();
    fetchSettings();
  }

  Future<void> _initTimezone() async {
    tz.initializeTimeZones();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // handle notification tapped if needed
      },
    );

    await _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notification permission denied. Notifications disabled.',
                ),
              ),
            );
          }
        }
      }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> fetchSettings() async {
    setState(() => isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        inAppNotificationsEnabled = true;
        popupNotificationsEnabled = true;
        chatNotificationsEnabled = true;
        reminderTime = null;
        isPrivate = false;
        isLoading = false;
      });
      return;
    }

    try {
      final res =
          await Supabase.instance.client
              .from('user_settings')
              .select(
                'in_app_notifications, popup_notifications, chat_notifications, reminder_time, is_private',
              )
              .eq('user_id', user.id)
              .maybeSingle();

      if (res == null) {
        await Supabase.instance.client.from('user_settings').insert({
          'user_id': user.id,
          'in_app_notifications': true,
          'popup_notifications': true,
          'chat_notifications': true,
          'reminder_time': null,
          'is_private': false,
        });
        return fetchSettings();
      }

      setState(() {
        inAppNotificationsEnabled = res['in_app_notifications'] ?? true;
        popupNotificationsEnabled = res['popup_notifications'] ?? true;
        chatNotificationsEnabled = res['chat_notifications'] ?? true;
        reminderTime = _parseTime(res['reminder_time']);
        isPrivate = res['is_private'] ?? false;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        inAppNotificationsEnabled = true;
        popupNotificationsEnabled = true;
        chatNotificationsEnabled = true;
        reminderTime = null;
        isPrivate = false;
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load settings: $e'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> updateInAppNotificationSetting(bool value) async {
    setState(() => inAppNotificationsEnabled = value);
    await _updateSetting('in_app_notifications', value);
  }

  Future<void> updatePopupNotificationSetting(bool value) async {
    setState(() => popupNotificationsEnabled = value);
    await _updateSetting('popup_notifications', value);
  }

  Future<void> updateChatNotificationSetting(bool value) async {
    setState(() => chatNotificationsEnabled = value);
    await _updateSetting('chat_notifications', value);
  }

  Future<void> updateReminderTime(TimeOfDay time) async {
    setState(() => reminderTime = time);
    await _updateSetting('reminder_time', _formatTime(time));
    await _scheduleDailyReminder(time);
  }

  Future<void> updatePrivateSetting(bool value) async {
    setState(() => isPrivate = value);
    await _updateSetting('is_private', value);
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('user_settings').upsert({
        'user_id': user.id,
        key: value,
      }, onConflict: 'user_id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleDailyReminder(TimeOfDay time) async {
    await _notificationsPlugin.cancel(0);

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminder',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails();

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      0,
      'LieDar Daily Reminder',
      "Don't forget to submit your lie today!",
      scheduledDate,
      platformDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_reminder',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Daily reminder set for ${time.format(context)}'),
        ),
      );
    }
  }

  Future<void> showChangePasswordDialog() async {
    final _formKey = GlobalKey<FormState>();
    String newPassword = '';
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: _formKey,
              child: TextFormField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                onChanged: (val) => newPassword = val,
                validator: (val) {
                  if (val == null || val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user == null) return;
                  try {
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(password: newPassword),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update password: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> showDeleteAccountDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
            content: const Text(
              'Are you sure you want to delete your account? This cannot be undone!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      await Supabase.instance.client.rpc(
        'remove_user',
        params: {'uuid': user.id},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully. Logging out...'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  final String privacyPolicyText = '''
LieDar is committed to protecting your privacy and ensuring that your personal information is handled securely and transparently.

- Information Collected: We collect basic account information (such as email and username) to provide you with customized and secure access. Usage data like app interactions may be collected anonymously to improve the app experience.

- Use of Information: Data is used solely to deliver app features, enable notifications, and enhance user experience. We respect your choices about notifications and privacy by providing settings to control these.

- Data Sharing: We do not sell or share your personal data with third parties except to comply with legal obligations or to provide necessary services with trusted partners under strict agreements.

- Security: We employ industry-standard security measures to protect your data. However, no app can guarantee absolute security; please practice safe device habits.

- Your Rights: You can update your privacy settings anytime, and you have the right to delete your account and data permanently.

By using LieDar, you agree to this privacy policy. For questions or concerns, contact support.
''';

  final String helpFaqsText = '''
Welcome to LieDar Help & FAQs! Here are answers to common questions to help you:

- How do I change my password?
  Tap "Change Password" in settings. Enter a new password of at least 6 characters.

- What notifications will I receive?
  Control in-app and popup notifications in settings. The daily reminder helps you remember to submit your lie.

- How is my data protected?
  We use secure servers and encrypt sensitive data.

- Can I make my account private?
  Yes, turn on "Private Account" to restrict posts to approved followers.

- How do I delete my account?
  Use "Delete Account" in settings. This deletes your data permanently.

- Who do I contact for support?
  Contact support via the Help & FAQs section or email [support@liedar.app](mailto:support@liedar.app).

Thank you for using LieDar! We’re here to help.
''';

  final String aboutText = '''
LieDar v1.0.0

LieDar is the premier app for sharing, exploring, and enjoying trending rumors, jokes, and viral stories - safely and responsibly. Created with a passion for fun and community.

- Stay updated with trending content.
- Customize notifications and reminders.
- Control your privacy.
- Join an engaging community.

Developed with Flutter and Supabase, LieDar is constantly evolving. Your feedback helps us improve.

© 2025 LieDar. All rights reserved.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 16, left: 24, bottom: 5),
                      child: Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Edit Profile'),
                      subtitle: const Text('Change your username or avatar'),
                      onTap: () {
                        Navigator.of(context).pushNamed('/profile');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your account password'),
                      onTap: showChangePasswordDialog,
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.only(top: 10, left: 24, bottom: 5),
                      child: Text(
                        'Notifications & Reminders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('In-App Notifications'),
                      subtitle: const Text(
                        'Receive notifications inside the app',
                      ),
                      value: inAppNotificationsEnabled ?? true,
                      activeColor: Colors.deepPurple,
                      onChanged: updateInAppNotificationSetting,
                    ),
                    SwitchListTile(
                      title: const Text('Pop-up Notifications'),
                      subtitle: const Text('Show pop-up notifications'),
                      value: popupNotificationsEnabled ?? true,
                      activeColor: Colors.deepPurple,
                      onChanged: updatePopupNotificationSetting,
                    ),
                    // New toggle for Chat Notifications:
                    SwitchListTile(
                      title: const Text('Chat Notifications'),
                      subtitle: const Text(
                        'Receive notifications for new chat messages',
                      ),
                      value: chatNotificationsEnabled ?? true,
                      activeColor: Colors.deepPurple,
                      onChanged: updateChatNotificationSetting,
                    ),
                    ListTile(
                      leading: const Icon(Icons.alarm),
                      title: const Text('Daily Reminder'),
                      subtitle: Text(
                        reminderTime != null
                            ? 'Every day at ${reminderTime!.format(context)}'
                            : 'No reminder set',
                      ),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                reminderTime ??
                                const TimeOfDay(hour: 21, minute: 0),
                          );
                          if (picked != null) {
                            await updateReminderTime(picked);
                          }
                        },
                        child: const Text('Set Time'),
                      ),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.only(top: 10, left: 24, bottom: 5),
                      child: Text(
                        'Privacy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Private Account'),
                      subtitle: const Text(
                        'Only approved followers can see your posts',
                      ),
                      value: isPrivate ?? false,
                      activeColor: Colors.deepPurple,
                      onChanged: updatePrivateSetting,
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy Policy'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Privacy Policy'),
                                content: SingleChildScrollView(
                                  child: Text(privacyPolicyText),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Delete Account'),
                      subtitle: const Text('Permanently delete your account'),
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: showDeleteAccountDialog,
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.only(top: 10, left: 24, bottom: 5),
                      child: Text(
                        'App & Support',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help & FAQs'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: const Text('Help & FAQs'),
                                content: SingleChildScrollView(
                                  child: Text(helpFaqsText),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: const Text('About'),
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'LieDar',
                          applicationVersion: 'v1.0.0',
                          applicationLegalese:
                              '© 2025 LieDar. All rights reserved.',
                          children: [Text(aboutText)],
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 25,
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Share App'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Share.share(
                            'Check out the LieDar app! Download here: https://yourappdownloadlink.example',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
      ),
    );
  }
}
