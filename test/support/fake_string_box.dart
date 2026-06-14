import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';

class FakeStringBox implements Box<String> {
  final _data = <dynamic, String>{};

  @override
  Iterable<String> get values => _data.values;

  @override
  Future<void> put(dynamic key, String value) async => _data[key] = value;

  @override
  Future<void> delete(dynamic key) async => _data.remove(key);

  @override
  String get name => 'fake';
  @override
  bool get isOpen => true;
  @override
  String? get path => null;
  @override
  bool get lazy => false;
  @override
  Iterable<dynamic> get keys => _data.keys;
  @override
  int get length => _data.length;
  @override
  bool get isEmpty => _data.isEmpty;
  @override
  bool get isNotEmpty => _data.isNotEmpty;
  @override
  dynamic keyAt(int index) => _data.keys.elementAt(index);
  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
  @override
  bool containsKey(dynamic key) => _data.containsKey(key);
  @override
  Future<void> putAt(int index, String value) async =>
      throw UnimplementedError();
  @override
  Future<void> putAll(Map<dynamic, String> entries) async =>
      entries.forEach((k, v) => _data[k] = v);
  @override
  Future<int> add(String value) async => throw UnimplementedError();
  @override
  Future<Iterable<int>> addAll(Iterable<String> values) async =>
      throw UnimplementedError();
  @override
  Future<void> deleteAt(int index) async => throw UnimplementedError();
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async =>
      keys.forEach(_data.remove);
  @override
  Future<void> compact() async {}
  @override
  Future<int> clear() async {
    final n = _data.length;
    _data.clear();
    return n;
  }
  @override
  Future<void> close() async {}
  @override
  Future<void> deleteFromDisk() async {}
  @override
  Future<void> flush() async {}

  @override
  Iterable<String> valuesBetween({dynamic startKey, dynamic endKey}) => [];
  @override
  String? get(dynamic key, {String? defaultValue}) =>
      _data[key] ?? defaultValue;
  @override
  String? getAt(int index) => _data.values.elementAt(index);
  @override
  Map<dynamic, String> toMap() => Map.of(_data);
}
