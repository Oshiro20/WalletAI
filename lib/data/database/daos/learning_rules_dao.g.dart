// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_rules_dao.dart';

// ignore_for_file: type=lint
mixin _$LearningRulesDaoMixin on DatabaseAccessor<AppDatabase> {
  $LearningRulesTable get learningRules => attachedDatabase.learningRules;
  LearningRulesDaoManager get managers => LearningRulesDaoManager(this);
}

class LearningRulesDaoManager {
  final _$LearningRulesDaoMixin _db;
  LearningRulesDaoManager(this._db);
  $$LearningRulesTableTableManager get learningRules =>
      $$LearningRulesTableTableManager(_db.attachedDatabase, _db.learningRules);
}
