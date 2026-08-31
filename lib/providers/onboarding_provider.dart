import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'category_provider.dart';
import 'wallet_provider.dart';
import 'auth_provider.dart';
import '../models/main_category.dart';
import '../models/sub_category.dart';
import '../models/wallet.dart';
import '../core/constants/default_categories.dart';

final onboardingCompletedProvider = StateNotifierProvider<OnboardingCompletedNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingCompletedNotifier(prefs);
});

class OnboardingCompletedNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const String _key = 'is_onboarding_completed';

  OnboardingCompletedNotifier(this._prefs) : super(false) {
    _loadState();
  }

  void _loadState() {
    state = _prefs.getBool(_key) ?? false;
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_key, true);
    state = true;
  }

  Future<void> resetOnboarding() async {
    await _prefs.setBool(_key, false);
    state = false;
  }
}

// Onboarding flow state model
class OnboardingFlowState {
  final int currentStep;
  final bool useTemplate;
  final List<MainCategory> selectedMainCategories;
  final List<SubCategory> selectedSubCategories;
  final List<Wallet> selectedWallets;
  final bool isSaving;

  OnboardingFlowState({
    this.currentStep = 1,
    this.useTemplate = true,
    this.selectedMainCategories = const [],
    this.selectedSubCategories = const [],
    this.selectedWallets = const [],
    this.isSaving = false,
  });

  OnboardingFlowState copyWith({
    int? currentStep,
    bool? useTemplate,
    List<MainCategory>? selectedMainCategories,
    List<SubCategory>? selectedSubCategories,
    List<Wallet>? selectedWallets,
    bool? isSaving,
  }) {
    return OnboardingFlowState(
      currentStep: currentStep ?? this.currentStep,
      useTemplate: useTemplate ?? this.useTemplate,
      selectedMainCategories: selectedMainCategories ?? this.selectedMainCategories,
      selectedSubCategories: selectedSubCategories ?? this.selectedSubCategories,
      selectedWallets: selectedWallets ?? this.selectedWallets,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

final onboardingFlowProvider = StateNotifierProvider<OnboardingFlowNotifier, OnboardingFlowState>((ref) {
  return OnboardingFlowNotifier(ref);
});

class OnboardingFlowNotifier extends StateNotifier<OnboardingFlowState> {
  final Ref _ref;

  OnboardingFlowNotifier(this._ref) : super(OnboardingFlowState()) {
    _initializeDefaults();
  }

  void _initializeDefaults() {
    // Set up default template categories and wallets in local state
    List<MainCategory> mainCats = [];
    List<SubCategory> subCats = [];
    
    for (var defaultCat in DefaultCategoriesData.defaultList) {
      mainCats.add(MainCategory(
        id: defaultCat.id,
        name: defaultCat.name,
        color: defaultCat.colorHex,
        emoji: defaultCat.emoji,
        order: defaultCat.order,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      for (var defaultSub in defaultCat.subCategories) {
        subCats.add(SubCategory(
          id: defaultSub.id,
          mainCategoryId: defaultCat.id,
          name: defaultSub.name,
          emoji: defaultSub.emoji,
          color: defaultCat.colorHex,
          order: defaultSub.order,
        ));
      }
    }

    int currentOrder = 0;
    final List<Wallet> wallets = DefaultCategoriesData.defaultWallets.map((wData) => Wallet(
      id: wData['id'],
      name: wData['name'],
      color: wData['color'],
      icon: wData['icon'],
      startingBalance: wData['startingBalance'],
      currentBalance: wData['startingBalance'],
      order: currentOrder++,
      createdAt: DateTime.now(),
    )).toList();

    state = OnboardingFlowState(
      selectedMainCategories: mainCats,
      selectedSubCategories: subCats,
      selectedWallets: wallets,
    );
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void setUseTemplate(bool val) {
    if (val) {
      _initializeDefaults();
      state = state.copyWith(useTemplate: true);
    } else {
      state = state.copyWith(
        useTemplate: false,
        selectedMainCategories: [],
        selectedSubCategories: [],
        selectedWallets: [],
      );
    }
  }

  void toggleMainCategorySelection(MainCategory category) {
    final list = List<MainCategory>.from(state.selectedMainCategories);
    final exists = list.any((c) => c.id == category.id);
    
    if (exists) {
      list.removeWhere((c) => c.id == category.id);
    } else {
      list.add(category);
    }
    state = state.copyWith(selectedMainCategories: list);
  }

  void addCustomMainCategory(MainCategory category) {
    final list = List<MainCategory>.from(state.selectedMainCategories)..add(category);
    state = state.copyWith(selectedMainCategories: list);
  }

  void addCustomSubCategory(SubCategory subCategory) {
    final list = List<SubCategory>.from(state.selectedSubCategories)..add(subCategory);
    state = state.copyWith(selectedSubCategories: list);
  }

  void addCustomWallet(Wallet wallet) {
    final list = List<Wallet>.from(state.selectedWallets)..add(wallet);
    state = state.copyWith(selectedWallets: list);
  }

  void updateWalletStartingBalance(String walletId, double balance) {
    final list = state.selectedWallets.map((w) {
      if (w.id == walletId) {
        return w.copyWith(startingBalance: balance, currentBalance: balance);
      }
      return w;
    }).toList();
    state = state.copyWith(selectedWallets: list);
  }

  Future<void> submitAndFinalize() async {
    state = state.copyWith(isSaving: true);
    final userId = _ref.read(authNotifierProvider).userId;
    if (userId == null) {
      state = state.copyWith(isSaving: false);
      return;
    }

    final catRepo = _ref.read(categoryRepositoryProvider);
    final walletRepo = _ref.read(walletRepositoryProvider);

    // Save all selected main categories and subcategories
    for (var cat in state.selectedMainCategories) {
      await catRepo.saveMainCategory(userId, cat);
    }
    for (var sub in state.selectedSubCategories) {
      // Only save if parent category is selected
      final isParentSelected = state.selectedMainCategories.any((c) => c.id == sub.mainCategoryId);
      if (isParentSelected) {
        await catRepo.saveSubCategory(userId, sub);
      }
    }

    // Save all selected wallets
    for (var wallet in state.selectedWallets) {
      await walletRepo.saveWallet(userId, wallet);
    }

    // Trigger loads
    await _ref.read(mainCategoriesProvider.notifier).loadCategories();
    await _ref.read(subCategoriesProvider.notifier).loadSubCategories();
    await _ref.read(rawWalletsProvider.notifier).loadWallets();

    // Mark completed
    await _ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
    state = state.copyWith(isSaving: false);
  }
}
