import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'couple_provider.dart';
import '../repositories/savings_goal_repository.dart';
import '../models/savings_goal.dart';

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SavingsGoalRepository(firestore);
});

final savingsGoalsStreamProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final roomId = ref.watch(coupleRoomIdProvider);
  if (roomId == null) return Stream.value([]);
  final repo = ref.watch(savingsGoalRepositoryProvider);
  return repo.watchSavingsGoals(roomId);
});
