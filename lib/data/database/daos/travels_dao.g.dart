// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'travels_dao.dart';

// ignore_for_file: type=lint
mixin _$TravelsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TravelsTable get travels => attachedDatabase.travels;
  TravelsDaoManager get managers => TravelsDaoManager(this);
}

class TravelsDaoManager {
  final _$TravelsDaoMixin _db;
  TravelsDaoManager(this._db);
  $$TravelsTableTableManager get travels =>
      $$TravelsTableTableManager(_db.attachedDatabase, _db.travels);
}
