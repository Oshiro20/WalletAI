// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_payments_dao.dart';

// ignore_for_file: type=lint
mixin _$RecurringPaymentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecurringPaymentsTable get recurringPayments =>
      attachedDatabase.recurringPayments;
  RecurringPaymentsDaoManager get managers => RecurringPaymentsDaoManager(this);
}

class RecurringPaymentsDaoManager {
  final _$RecurringPaymentsDaoMixin _db;
  RecurringPaymentsDaoManager(this._db);
  $$RecurringPaymentsTableTableManager get recurringPayments =>
      $$RecurringPaymentsTableTableManager(
        _db.attachedDatabase,
        _db.recurringPayments,
      );
}
