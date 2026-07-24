import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/voice_provider.dart';
import '../utils/app_theme.dart';

/// Settings screen.
///
/// Bug fix (Module 1 — C5/H5)
/// ----------------------------
/// The original implementation was a [StatelessWidget] that created a
/// [TextEditingController] inside [build()]:
///
///   TextEditingController(text: appProvider.emergencyContact)
///
/// This is a memory leak: a new controller is allocated on every rebuild
/// and the old one is never disposed.  On a settings screen that reacts to
/// provider changes, this can allocate dozens of controllers per session.
///
/// Fix: Converted to [StatefulWidget].  The controller is created once in
/// [initState], updated when the provider value changes via [didChangeDependencies],
/// and properly disposed in [dispose].
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _emergencyContactController;

  @override
  void initState() {
    super.initState();
    // Read the initial value synchronously from the provider.
    final initialContact =
        context.read<AppProvider>().emergencyContact;
    _emergencyContactController =
        TextEditingController(text: initialContact);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the controller when the provider value changes externally
    // (e.g. after a SharedPreferences reload).
    final currentContact = context.read<AppProvider>().emergencyContact;
    if (_emergencyContactController.text != currentContact) {
      _emergencyContactController.text = currentContact;
    }
  }

  @override
  void dispose() {
    _emergencyContactController.dispose(); // ← was leaking before this fix
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final voiceProvider = context.read<VoiceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () => voiceProvider.speak('Settings screen.'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Appearance'),
          // Dark mode toggle
          _settingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Easier on eyes in low light',
            trailing: Switch(
              value: appProvider.themeMode == ThemeMode.dark,
              onChanged: (val) {
                appProvider.setThemeMode(val);
                voiceProvider.speak(val ? 'Dark mode on' : 'Light mode on');
              },
              activeColor: AppTheme.ibmBlue,
            ),
          ),
          // High contrast
          _settingTile(
            icon: Icons.contrast_outlined,
            title: 'High Contrast Mode',
            subtitle: 'Maximize readability',
            trailing: Switch(
              value: appProvider.highContrastMode,
              onChanged: (val) {
                appProvider.setHighContrastMode(val);
                voiceProvider.speak(
                  val ? 'High contrast on' : 'High contrast off',
                );
              },
              activeColor: AppTheme.ibmBlue,
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('Text & Voice'),

          // Text size slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.text_fields_outlined,
                        color: AppTheme.ibmBlue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Text Size',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${(appProvider.textScaleFactor * 100).toInt()}%',
                      style: const TextStyle(
                        color: AppTheme.ibmCoolGray,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: appProvider.textScaleFactor,
                  min: 0.8,
                  max: 2.0,
                  divisions: 12,
                  label: '${(appProvider.textScaleFactor * 100).toInt()}%',
                  onChanged: (val) => appProvider.setTextScaleFactor(val),
                  activeColor: AppTheme.ibmBlue,
                ),
              ],
            ),
          ),

          // Speech rate
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_outlined, color: AppTheme.ibmBlue),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Speech Rate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${appProvider.speechRate.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: AppTheme.ibmCoolGray,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: appProvider.speechRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${appProvider.speechRate.toStringAsFixed(1)}x',
                  onChanged: (val) {
                    appProvider.setSpeechRate(val);
                    voiceProvider.updateSettings(rate: val);
                  },
                  activeColor: AppTheme.ibmBlue,
                ),
              ],
            ),
          ),

          // Language selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.language_outlined, color: AppTheme.ibmBlue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Voice Language',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                DropdownButton<String>(
                  value: appProvider.language,
                  items: const [
                    DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                    DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                    DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                    DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
                    DropdownMenuItem(value: 'te-IN', child: Text('Telugu')),
                    DropdownMenuItem(value: 'kn-IN', child: Text('Kannada')),
                  ],
                  onChanged: (lang) {
                    if (lang != null) {
                      appProvider.setLanguage(lang);
                      voiceProvider.updateSettings(language: lang);
                    }
                  },
                  underline: const SizedBox(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('Connectivity'),

          _settingTile(
            icon: Icons.wifi_off_outlined,
            title: 'Offline Mode',
            subtitle: 'Works without internet',
            trailing: Switch(
              value: appProvider.offlineMode,
              onChanged: (val) {
                appProvider.setOfflineMode(val);
                voiceProvider.speak(
                  val ? 'Offline mode on' : 'Online mode on',
                );
              },
              activeColor: AppTheme.ibmBlue,
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('Emergency SOS'),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency Contact Number',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  // Fix (Module 1): use the class-level controller created
                  // in initState and disposed in dispose().
                  // The old inline TextEditingController(text: ...) was
                  // leaking one controller object per rebuild.
                  controller: _emergencyContactController,
                  decoration: InputDecoration(
                    hintText: '+91 9999999999',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  onSubmitted: (val) => appProvider.setEmergencyContact(val),
                  onChanged: (val) {
                    if (val.length >= 10) {
                      appProvider.setEmergencyContact(val);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('About'),

          _settingTile(
            icon: Icons.info_outlined,
            title: 'SignSense AI',
            subtitle: 'Version 1.0.0 — IBM SkillsBuild Project',
            trailing: null,
          ),
          _settingTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Accessibility Mission',
            subtitle: 'Empowering visually impaired individuals worldwide',
            trailing: null,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.ibmBlue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.ibmBlue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: AppTheme.ibmCoolGray, fontSize: 12)),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
