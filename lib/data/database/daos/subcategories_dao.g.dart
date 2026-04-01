// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subcategories_dao.dart';

// ignore_for_file: type=lint
mixin _$SubcategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SubcategoriesTable get subcategories => attachedDatabase.subcategories;
  SubcategoriesDaoManager get managers => SubcategoriesDaoManager(this);
}

class SubcategoriesDaoManager {
  final _$SubcategoriesDaoMixin _db;
  SubcategoriesDaoManager(this._db);
  $$SubcategoriesTableTableManager get subcategories =>
      $$SubcategoriesTableTableManager(_db.attachedDatabase, _db.subcategories);
}
