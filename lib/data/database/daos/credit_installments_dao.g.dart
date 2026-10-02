// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credit_installments_dao.dart';

// ignore_for_file: type=lint
mixin _$CreditInstallmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CreditInstallmentsTable get creditInstallments =>
      attachedDatabase.creditInstallments;
  CreditInstallmentsDaoManager get managers =>
      CreditInstallmentsDaoManager(this);
}

class CreditInstallmentsDaoManager {
  final _$CreditInstallmentsDaoMixin _db;
  CreditInstallmentsDaoManager(this._db);
  $$CreditInstallmentsTableTableManager get creditInstallments =>
      $$CreditInstallmentsTableTableManager(
        _db.attachedDatabase,
        _db.creditInstallments,
      );
}
