import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized. Please initialize it in main().');
});

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});

class ThemeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const String _key = 'is_dark_theme';

  ThemeNotifier(this._prefs) : super(false) {
    _loadTheme();
  }

  void _loadTheme() {
    state = _prefs.getBool(_key) ?? false;
  }

  void toggleTheme() {
    state = !state;
    _prefs.setBool(_key, state);
  }
}
