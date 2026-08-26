import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/savings_goal.dart';

class SavingsGoalRepository {
  final FirebaseFirestore? _firestore;

  SavingsGoalRepository(this._firestore);

  bool get _isAvailable => _firestore != null;

  /// Stream of savings goals for a couple room
  Stream<List<SavingsGoal>> watchSavingsGoals(String roomId) {
    if (!_isAvailable) return Stream.value([]);
    return _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .collection('savings_goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SavingsGoal.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Create a new savings goal
  Future<SavingsGoal> createSavingsGoal(String roomId, SavingsGoal goal) async {
    if (!_isAvailable) return goal;
    final ref = _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .collection('savings_goals')
        .doc();

    final newGoal = SavingsGoal(
      id: ref.id,
      title: goal.title,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      emoji: goal.emoji,
      targetDate: goal.targetDate,
      contributions: goal.contributions,
      createdAt: DateTime.now(),
    );

    await ref.set(newGoal.toMap());
    return newGoal;
  }

  /// Add a savings contribution to a goal
  Future<void> addContribution(
    String roomId,
    String goalId,
    SavingsContribution contribution,
  ) async {
    if (!_isAvailable) return;
    final ref = _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .collection('savings_goals')
        .doc(goalId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final goal = SavingsGoal.fromMap(doc.data()!, doc.id);
    final updatedContributions = [...goal.contributions, contribution];
    final updatedCurrentAmount = goal.currentAmount + contribution.amount;

    await ref.update({
      'currentAmount': updatedCurrentAmount,
      'contributions': updatedContributions.map((c) => c.toMap()).toList(),
    });
  }

  /// Delete a savings goal
  Future<void> deleteSavingsGoal(String roomId, String goalId) async {
    if (!_isAvailable) return;
    await _firestore!
        .collection('couple_rooms')
        .doc(roomId)
        .collection('savings_goals')
        .doc(goalId)
        .delete();
  }
}
