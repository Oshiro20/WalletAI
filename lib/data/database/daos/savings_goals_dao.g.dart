// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_goals_dao.dart';

// ignore_for_file: type=lint
mixin _$SavingsGoalsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavingsGoalsTable get savingsGoals => attachedDatabase.savingsGoals;
  SavingsGoalsDaoManager get managers => SavingsGoalsDaoManager(this);
}

class SavingsGoalsDaoManager {
  final _$SavingsGoalsDaoMixin _db;
  SavingsGoalsDaoManager(this._db);
  $$SavingsGoalsTableTableManager get savingsGoals =>
      $$SavingsGoalsTableTableManager(_db.attachedDatabase, _db.savingsGoals);
}
