import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Keys ───────────────────────────────────────────────────────────────────────
abstract final class _Keys {
  static const String haptics = 'settings_haptics';
  static const String sound = 'settings_sound';
  static const String showTimer = 'settings_show_timer';
  static const String localPlayerAName = 'settings_local_player_a_name';
  static const String localPlayerBName = 'settings_local_player_b_name';
  static const String youName = 'settings_you_name';
  static const String aiName = 'settings_ai_name';
}

// ── Model ──────────────────────────────────────────────────────────────────────
class SettingsState {
  const SettingsState({
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.showTimer = true,
    this.localPlayerAName = 'Player A',
    this.localPlayerBName = 'Player B',
    this.youName = 'You',
    this.aiName = 'Rival',
  });

  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool showTimer;
  final String localPlayerAName;
  final String localPlayerBName;
  final String youName;
  final String aiName;

  SettingsState copyWith({
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? showTimer,
    String? localPlayerAName,
    String? localPlayerBName,
    String? youName,
    String? aiName,
  }) =>
      SettingsState(
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        showTimer: showTimer ?? this.showTimer,
        localPlayerAName: localPlayerAName ?? this.localPlayerAName,
        localPlayerBName: localPlayerBName ?? this.localPlayerBName,
        youName: youName ?? this.youName,
        aiName: aiName ?? this.aiName,
      );
}

/// Default opponent display name; migrates legacy saved value `AI`.
String _defaultOpponentName(String? stored) {
  if (stored == null || stored.isEmpty) return 'Rival';
  if (stored == 'AI') return 'Rival';
  return stored;
}

// ── Provider ───────────────────────────────────────────────────────────────────
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadFuture = _load();
  }

  SharedPreferences? _prefs;
  Future<void>? _loadFuture;

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      hapticsEnabled: _prefs!.getBool(_Keys.haptics) ?? true,
      soundEnabled: _prefs!.getBool(_Keys.sound) ?? true,
      showTimer: _prefs!.getBool(_Keys.showTimer) ?? true,
      localPlayerAName: _prefs!.getString(_Keys.localPlayerAName) ?? 'Player A',
      localPlayerBName: _prefs!.getString(_Keys.localPlayerBName) ?? 'Player B',
      youName: _prefs!.getString(_Keys.youName) ?? 'You',
      aiName: _defaultOpponentName(_prefs!.getString(_Keys.aiName)),
    );
  }

  Future<void> _ensureLoaded() async {
    if (_prefs != null) return;
    _loadFuture ??= _load();
    await _loadFuture;
  }

  void setHaptics(bool v) {
    _prefs?.setBool(_Keys.haptics, v);
    state = state.copyWith(hapticsEnabled: v);
  }

  void setSound(bool v) {
    _prefs?.setBool(_Keys.sound, v);
    state = state.copyWith(soundEnabled: v);
  }

  void setShowTimer(bool v) {
    _prefs?.setBool(_Keys.showTimer, v);
    state = state.copyWith(showTimer: v);
  }

  void setLocalPlayerAName(String v) {
    _prefs?.setString(_Keys.localPlayerAName, v);
    state = state.copyWith(localPlayerAName: v);
  }

  void commitLocalPlayerAName(String v) {
    final name = v.trim().isEmpty ? 'Player A' : v.trim();
    _prefs?.setString(_Keys.localPlayerAName, name);
    state = state.copyWith(localPlayerAName: name);
  }

  void setLocalPlayerBName(String v) {
    _prefs?.setString(_Keys.localPlayerBName, v);
    state = state.copyWith(localPlayerBName: v);
  }

  void commitLocalPlayerBName(String v) {
    final name = v.trim().isEmpty ? 'Player B' : v.trim();
    _prefs?.setString(_Keys.localPlayerBName, name);
    state = state.copyWith(localPlayerBName: name);
  }

  void setYouName(String v) {
    _prefs?.setString(_Keys.youName, v);
    state = state.copyWith(youName: v);
  }

  void commitYouName(String v) {
    final name = v.trim().isEmpty ? 'You' : v.trim();
    _prefs?.setString(_Keys.youName, name);
    state = state.copyWith(youName: name);
  }

  void setAiName(String v) {
    _prefs?.setString(_Keys.aiName, v);
    state = state.copyWith(aiName: v);
  }

  void commitAiName(String v) {
    final name = v.trim().isEmpty ? 'Rival' : v.trim();
    _prefs?.setString(_Keys.aiName, name);
    state = state.copyWith(aiName: name);
  }

  Future<void> applyAccountDisplayNameIfDefaults(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _ensureLoaded();
    if (state.localPlayerAName == 'Player A') {
      setLocalPlayerAName(trimmed);
    }
    if (state.youName == 'You') {
      commitYouName(trimmed);
    }
  }

  /// Clears gameplay prefs after account deletion (keeps onboarding seen).
  Future<void> clearAllLocalData() async {
    await _ensureLoaded();
    final prefs = _prefs;
    if (prefs == null) return;
    final onboardingSeen = prefs.getBool('onboarding_seen_v1');
    await prefs.clear();
    if (onboardingSeen == true) {
      await prefs.setBool('onboarding_seen_v1', true);
    }
    state = const SettingsState();
  }
}
