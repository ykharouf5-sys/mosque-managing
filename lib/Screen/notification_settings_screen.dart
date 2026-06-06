import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaman/widget/variable.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _prayerNotificationsEnabled = true;
  bool _chatNotificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _selectedSound = 'default';
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Load notification preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _prayerNotificationsEnabled = prefs.getBool('prayer_notifications_enabled') ?? true;
        _chatNotificationsEnabled = prefs.getBool('chat_notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('notification_sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('notification_vibration_enabled') ?? true;
        _selectedSound = prefs.getString('notification_sound') ?? 'default';
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading preferences: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Save a preference
  Future<void> _savePreference(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
      print('✅ Saved preference: $key = $value');
    } catch (e) {
      print('❌ Error saving preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        title: const Text(
          'إعدادات الإشعارات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: textcolor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prayer Notifications Section
                _buildSectionHeader('إشعارات الصلاة', Icons.mosque),
                _buildSettingCard(
                  title: 'تفعيل إشعارات الصلاة',
                  subtitle: 'تلقي إشعارات عند حلول أوقات الصلوات الخمس',
                  icon: Icons.notifications_active,
                  value: _prayerNotificationsEnabled,
                  onChanged: (value) {
                    setState(() => _prayerNotificationsEnabled = value);
                    _savePreference('prayer_notifications_enabled', value);
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Chat Notifications Section
                _buildSectionHeader('إشعارات الدردشة', Icons.chat),
                _buildSettingCard(
                  title: 'تفعيل إشعارات الدردشة',
                  subtitle: 'تلقي إشعارات عند وصول رسائل جديدة',
                  icon: Icons.message,
                  value: _chatNotificationsEnabled,
                  onChanged: (value) {
                    setState(() => _chatNotificationsEnabled = value);
                    _savePreference('chat_notifications_enabled', value);
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Sound & Vibration Section
                _buildSectionHeader('الصوت والاهتزاز', Icons.volume_up),
                _buildSettingCard(
                  title: 'الصوت',
                  subtitle: 'تشغيل صوت عند الإشعارات',
                  icon: Icons.music_note,
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                    _savePreference('notification_sound_enabled', value);
                  },
                ),
                const SizedBox(height: 12),
                _buildSettingCard(
                  title: 'الاهتزاز',
                  subtitle: 'اهتزاز الجهاز عند الإشعارات',
                  icon: Icons.vibration,
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() => _vibrationEnabled = value);
                    _savePreference('notification_vibration_enabled', value);
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Sound Selection
                _buildSectionHeader('نغمة الإشعار', Icons.audiotrack),
                _buildSoundSelector(),
                
                const SizedBox(height: 32),
                
                // Reset Button
                _buildResetButton(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, color: regsin, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: textcolor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: regsin.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: regsin, size: 24),
        ),
        activeThumbColor: regsin,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildSoundSelector() {
    final sounds = {
      'default': 'افتراضي',
      'azan': 'أذان',
      'bell': 'جرس',
      'chime': 'رنين',
      'none': 'بدون صوت',
    };

    return Container(
      decoration: BoxDecoration(
        color: textcolor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: regsin, size: 20),
              const SizedBox(width: 8),
              const Text(
                'اختر النغمة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sounds.entries.map((entry) {
            return RadioListTile<String>(
              value: entry.key,
              groupValue: _selectedSound,
              onChanged: _soundEnabled
                  ? (value) {
                      if (value != null) {
                        setState(() => _selectedSound = value);
                        _savePreference('notification_sound', value);
                      }
                    }
                  : null,
              title: Text(
                entry.value,
                style: TextStyle(
                  color: _soundEnabled ? Colors.white : Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              activeColor: regsin,
              dense: true,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: textcolor,
            title: const Text(
              'إعادة تعيين الإعدادات',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'هل تريد إعادة جميع الإعدادات إلى القيم الافتراضية؟',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: regsin),
                child: const Text('إعادة تعيين'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('prayer_notifications_enabled');
          await prefs.remove('chat_notifications_enabled');
          await prefs.remove('notification_sound_enabled');
          await prefs.remove('notification_vibration_enabled');
          await prefs.remove('notification_sound');
          
          setState(() {
            _prayerNotificationsEnabled = true;
            _chatNotificationsEnabled = true;
            _soundEnabled = true;
            _vibrationEnabled = true;
            _selectedSound = 'default';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم إعادة تعيين الإعدادات'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('إعادة تعيين الإعدادات'),
      style: ElevatedButton.styleFrom(
        backgroundColor: textcolor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: regsin.withOpacity(0.5)),
        ),
      ),
    );
  }
}
