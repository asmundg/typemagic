import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings with SharedPreferences persistence.
class AppSettings {
  final String themeId;
  final bool soundEnabled;
  final double soundVolume;
  final String stopOnError; // 'off', 'letter', 'word'
  final String defaultTestMode; // 'time', 'words', 'sentences'
  final int defaultTestValue; // 30, 25, 3
  final int defaultTier; // 1-5
  final String fontSize; // 'small', 'medium', 'large'
  final int minAccuracy; // 0 = off, otherwise minimum accuracy % (e.g. 80, 90, 95)

  const AppSettings({
    this.themeId = 'dark',
    this.soundEnabled = true,
    this.soundVolume = 0.5,
    this.stopOnError = 'off',
    this.defaultTestMode = 'time',
    this.defaultTestValue = 30,
    this.defaultTier = 1,
    this.fontSize = 'medium',
    this.minAccuracy = 0,
  });

  AppSettings copyWith({
    String? themeId,
    bool? soundEnabled,
    double? soundVolume,
    String? stopOnError,
    String? defaultTestMode,
    int? defaultTestValue,
    int? defaultTier,
    String? fontSize,
    int? minAccuracy,
  }) {
    return AppSettings(
      themeId: themeId ?? this.themeId,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      stopOnError: stopOnError ?? this.stopOnError,
      defaultTestMode: defaultTestMode ?? this.defaultTestMode,
      defaultTestValue: defaultTestValue ?? this.defaultTestValue,
      defaultTier: defaultTier ?? this.defaultTier,
      fontSize: fontSize ?? this.fontSize,
      minAccuracy: minAccuracy ?? this.minAccuracy,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _prefix = 'settings_';

  @override
  AppSettings build() {
    _loadAsync();
    return const AppSettings();
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      themeId: prefs.getString('${_prefix}themeId') ?? 'dark',
      soundEnabled: prefs.getBool('${_prefix}soundEnabled') ?? true,
      soundVolume: prefs.getDouble('${_prefix}soundVolume') ?? 0.5,
      stopOnError: prefs.getString('${_prefix}stopOnError') ?? 'off',
      defaultTestMode: prefs.getString('${_prefix}defaultTestMode') ?? 'time',
      defaultTestValue: prefs.getInt('${_prefix}defaultTestValue') ?? 30,
      defaultTier: prefs.getInt('${_prefix}defaultTier') ?? 1,
      fontSize: prefs.getString('${_prefix}fontSize') ?? 'medium',
      minAccuracy: prefs.getInt('${_prefix}minAccuracy') ?? 0,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}themeId', state.themeId);
    await prefs.setBool('${_prefix}soundEnabled', state.soundEnabled);
    await prefs.setDouble('${_prefix}soundVolume', state.soundVolume);
    await prefs.setString('${_prefix}stopOnError', state.stopOnError);
    await prefs.setString('${_prefix}defaultTestMode', state.defaultTestMode);
    await prefs.setInt('${_prefix}defaultTestValue', state.defaultTestValue);
    await prefs.setInt('${_prefix}defaultTier', state.defaultTier);
    await prefs.setString('${_prefix}fontSize', state.fontSize);
    await prefs.setInt('${_prefix}minAccuracy', state.minAccuracy);
  }

  void setTheme(String themeId) {
    state = state.copyWith(themeId: themeId);
    _save();
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(soundEnabled: enabled);
    _save();
  }

  void setSoundVolume(double volume) {
    state = state.copyWith(soundVolume: volume.clamp(0.0, 1.0));
    _save();
  }

  void setStopOnError(String mode) {
    state = state.copyWith(stopOnError: mode);
    _save();
  }

  void setDefaultTestMode(String mode) {
    state = state.copyWith(defaultTestMode: mode);
    _save();
  }

  void setDefaultTestValue(int value) {
    state = state.copyWith(defaultTestValue: value);
    _save();
  }

  void setDefaultTier(int tier) {
    state = state.copyWith(defaultTier: tier.clamp(1, 5));
    _save();
  }

  void setFontSize(String size) {
    state = state.copyWith(fontSize: size);
    _save();
  }

  void setMinAccuracy(int value) {
    state = state.copyWith(minAccuracy: value.clamp(0, 100));
    _save();
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    state = const AppSettings();
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
