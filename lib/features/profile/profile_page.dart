import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../services/app_notification_service.dart';
import '../../services/notification_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _nameKey = 'profile_name';
  static const _surnameKey = 'profile_surname';
  static const _birthdayKey = 'profile_birthday';

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isEditing = false;
  String _storedName = '';
  String _storedSurname = '';
  DateTime? _storedBirthday;
  DateTime? _tempBirthday;

  bool _localNotificationsEnabled = true;
  bool _remoteNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _storedName = prefs.getString(_nameKey) ?? '';
      _storedSurname = prefs.getString(_surnameKey) ?? '';
      _nameController.text = _storedName;
      _surnameController.text = _storedSurname;

      final birthdayString = prefs.getString(_birthdayKey);
      _storedBirthday = birthdayString != null
          ? DateTime.tryParse(birthdayString)
          : null;
      _tempBirthday = _storedBirthday;
    });

    final localEnabled =
        await NotificationService.instance.isLocalNotificationsEnabled;
    final remoteEnabled =
        await NotificationService.instance.isRemoteNotificationsEnabled;

    if (mounted) {
      setState(() {
        _localNotificationsEnabled = localEnabled;
        _remoteNotificationsEnabled = remoteEnabled;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final newName = _nameController.text.trim();
    final newSurname = _surnameController.text.trim();

    await prefs.setString(_nameKey, newName);
    await prefs.setString(_surnameKey, newSurname);
    if (_tempBirthday != null) {
      await prefs.setString(_birthdayKey, _tempBirthday!.toIso8601String());
    } else {
      await prefs.remove(_birthdayKey);
    }

    if (!mounted) return;
    setState(() {
      _storedName = newName;
      _storedSurname = newSurname;
      _storedBirthday = _tempBirthday;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.profileSaved)),
    );
    await AppNotificationService.instance.addProfileUpdated();
  }

  void _cancelEdit() {
    setState(() {
      _nameController.text = _storedName;
      _surnameController.text = _storedSurname;
      _tempBirthday = _storedBirthday;
      _isEditing = false;
    });
  }

  Future<void> _signInWithGoogle() async {
    if (Firebase.apps.isEmpty) {
      _showSnack('Firebase is not configured for this platform yet.');
      return;
    }

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _addWelcomeNotificationOnce(googleUser.email);
      if (mounted) setState(() {});
    } on GoogleSignInException catch (error) {
      if (mounted) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          _showSnack('Sign In Cancelled');
        } else {
          _showSnack(
            AppLocalizations.of(
              context,
            )!.profileGoogleSignInFailed(error.toString()),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        _showSnack(
          AppLocalizations.of(
            context,
          )!.profileGoogleSignInFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _signOut() async {
    if (Firebase.apps.isNotEmpty) {
      await FirebaseAuth.instance.signOut();
    }
    await GoogleSignIn.instance.signOut();
    if (mounted) setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addWelcomeNotificationOnce(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'welcome_notification_${email ?? 'user'}';
    if (prefs.getBool(key) ?? false) return;
    await AppNotificationService.instance.addWelcome();
    await prefs.setBool(key, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  User? _currentUser() {
    try {
      if (Firebase.apps.isNotEmpty) return FirebaseAuth.instance.currentUser;
    } catch (error, stackTrace) {
      debugPrint('Profile user lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return null;
  }

  _ProfileSummary _profileSummary(User? user) {
    final authName = user?.displayName?.trim();
    final storedFullName = '$_storedName $_storedSurname'.trim();
    final email = user?.email?.trim();
    final emailUsername = email != null && email.contains('@')
        ? email.split('@').first
        : null;

    final displayName = storedFullName.isNotEmpty
        ? storedFullName
        : authName != null && authName.isNotEmpty
        ? authName
        : emailUsername != null && emailUsername.isNotEmpty
        ? emailUsername
        : AppLocalizations.of(context)!.guestUser;

    return _ProfileSummary(
      displayName: displayName,
      email: email ?? AppLocalizations.of(context)!.emailNotConnected,
    );
  }

  Widget _buildAvatar(User? user) {
    if (user?.photoURL != null) {
      return CircleAvatar(
        radius: 38,
        backgroundImage: NetworkImage(user!.photoURL!),
        backgroundColor: AppColors.border,
      );
    }
    return const CircleAvatar(
      radius: 38,
      backgroundColor: AppColors.sand,
      child: Icon(Icons.person_rounded, size: 38, color: AppColors.sage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = _currentUser();
    final summary = _profileSummary(user);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 116),
        children: [
          Text(
            l10n.profileTitle,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 20),
          _profileHeaderCard(context, l10n, user, summary),
          const SizedBox(height: 16),
          _personalInfoCard(l10n, summary),
          const SizedBox(height: 16),
          _notificationSettingsCard(l10n),
          const SizedBox(height: 18),
          _authButton(l10n, user),
        ],
      ),
    );
  }

  Widget _profileHeaderCard(
    BuildContext context,
    AppLocalizations l10n,
    User? user,
    _ProfileSummary summary,
  ) {
    return _ProfileCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(user),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      summary.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded),
              label: Text(
                _isEditing ? l10n.profileEditCancel : l10n.editProfile,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 18),
            _editProfileForm(l10n),
          ],
        ],
      ),
    );
  }

  Widget _editProfileForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration(l10n.profileNameLabel),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? l10n.profileNameRequired
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _surnameController,
            decoration: _inputDecoration(l10n.profileSurnameLabel),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? l10n.profileSurnameRequired
                : null,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _tempBirthday ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _tempBirthday = picked);
            },
            child: InputDecorator(
              decoration: _inputDecoration(l10n.profileBirthdayLabel),
              child: Text(
                _formatBirthday(_tempBirthday) ?? l10n.profileBirthdayNotSet,
                style: TextStyle(
                  color: _tempBirthday != null
                      ? AppColors.ink
                      : AppColors.muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(l10n.profileEditCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(l10n.profileEditConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _personalInfoCard(AppLocalizations l10n, _ProfileSummary summary) {
    final nameValue = _storedName.isNotEmpty
        ? _storedName
        : summary.displayName == l10n.guestUser
        ? l10n.notSet
        : summary.displayName.split(' ').first;

    return _ProfileCard(
      title: l10n.personalInformation,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.badge_rounded,
            label: l10n.profileNameLabel,
            value: nameValue,
          ),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: l10n.profileSurnameLabel,
            value: _storedSurname.isNotEmpty ? _storedSurname : l10n.notSet,
          ),
          _InfoRow(
            icon: Icons.cake_rounded,
            label: l10n.profileBirthdayLabel,
            value: _formatBirthday(_storedBirthday) ?? l10n.notSet,
          ),
        ],
      ),
    );
  }

  Widget _notificationSettingsCard(AppLocalizations l10n) {
    return _ProfileCard(
      title: l10n.profileSettingsTitle,
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _localNotificationsEnabled,
            onChanged: (value) async {
              setState(() => _localNotificationsEnabled = value);
              await NotificationService.instance.setLocalNotificationsEnabled(
                value,
              );
            },
            secondary: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.sage,
            ),
            title: Text(
              l10n.profileSettingAuthReminders,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            activeTrackColor: AppColors.sage,
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _remoteNotificationsEnabled,
            onChanged: (value) async {
              setState(() => _remoteNotificationsEnabled = value);
              await NotificationService.instance.setRemoteNotificationsEnabled(
                value,
              );
            },
            secondary: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.clay,
            ),
            title: Text(
              l10n.profileSettingAiUpdates,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            activeTrackColor: AppColors.sage,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_rounded, color: AppColors.sage),
            title: Text(
              l10n.profileSettingLanguage,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: Localizations.localeOf(context).languageCode,
                icon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.ink,
                ),
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                onChanged: (newLanguageCode) {
                  if (newLanguageCode != null) {
                    DecoratorAiApp.setLocale(context, Locale(newLanguageCode));
                  }
                },
                items: [
                  DropdownMenuItem(
                    value: 'en',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇺🇸', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(l10n.languageEnglish),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'tr',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇹🇷', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(l10n.languageTurkish),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authButton(AppLocalizations l10n, User? user) {
    if (user == null) {
      return OutlinedButton.icon(
        onPressed: _signInWithGoogle,
        icon: Image.asset(
          'assets/brand_logo/google.png',
          width: 22,
          height: 22,
        ),
        label: Text(l10n.profileSignInGoogle),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _signOut,
      icon: const Icon(Icons.logout_rounded),
      label: Text(l10n.profileSignOut),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.cream,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.sage, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary {
  const _ProfileSummary({required this.displayName, required this.email});

  final String displayName;
  final String email;
}

String? _formatBirthday(DateTime? birthday) {
  if (birthday == null) return null;
  final day = birthday.day.toString().padLeft(2, '0');
  final month = birthday.month.toString().padLeft(2, '0');
  return '$day/$month/${birthday.year}';
}
