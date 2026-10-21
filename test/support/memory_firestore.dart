// Firestoreの公開インターフェースを実装するテスト専用ダブル。
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Repositoryの保存内容と失敗時の一括性を確認するテスト用ストア。
/// Firestoreの競合リトライやSecurity Rulesの代替ではない。
class MemoryFirestore implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  int _nextId = 0;
  bool failBatch = false;
  final changes = StreamController<void>.broadcast(sync: true);
  Future<void> dispose() => changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await handler(transaction);
    transaction.commit();
    return result;
  }

  @override
  WriteBatch batch() => _Batch(this);
}

class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.store, this.path);
  final MemoryFirestore store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    store.documents[path] = Map.of(data);
  }

  @override
  Future<void> delete() async {
    store.documents.remove(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(store, '$path/$collectionPath');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(this, store.documents[path]);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield await get();
    await for (final _ in store.changes.stream) {
      yield await get();
    }
  }
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.reference, Map<String, dynamic>? data)
    : _data = data == null ? null : Map.of(data);
  final Map<String, dynamic>? _data;
  @override
  final DocumentReference<Map<String, dynamic>> reference;
  @override
  String get id => reference.id;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QueryDoc extends _Snapshot
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDoc(super.reference, super.data);
  @override
  Map<String, dynamic> data() => super.data()!;
}

class _QuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path, [this.field, this.value]);
  final MemoryFirestore store;
  @override
  final String path;
  final Object? field;
  final Object? value;
  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    final reference = doc();
    await reference.set(data);
    return reference;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Doc(store, '${this.path}/${path ?? 'generated-${store._nextId++}'}');
  // このテストダブルではFirestore側ソートを検証しない。
  @override
  Query<Map<String, dynamic>> orderBy(
    Object field, {
    bool descending = false,
  }) => this;
  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) => _Collection(store, path, field, isEqualTo);
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    return _QuerySnapshot(
      store.documents.entries
          .where(
            (entry) =>
                entry.key.startsWith('$path/') &&
                entry.key.split('/').length == path.split('/').length + 1 &&
                (field == null || entry.value[field] == value),
          )
          .map((entry) => _QueryDoc(_Doc(store, entry.key), entry.value))
          .toList(),
    );
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) async* {
    yield await get();
    await for (final _ in store.changes.stream) {
      yield await get();
    }
  }
}

mixin _Writes {
  MemoryFirestore get store;
  final writes = <void Function()>[];
  Map<String, dynamic> _resolved(Map<Object, Object?> data) => {
    for (final entry in data.entries)
      entry.key as String: entry.value is FieldValue
          ? Timestamp.now()
          : entry.value,
  };
  void updateDoc(DocumentReference reference, Map<Object, Object?> data) =>
      writes.add(
        () => store.documents[reference.path]!.addAll(_resolved(data)),
      );
  void setDoc(DocumentReference reference, Object? data) => writes.add(
    () => store.documents[reference.path] = _resolved(
      data as Map<Object, Object?>,
    ),
  );
  void commit() {
    for (final write in writes) {
      write();
    }
    store.changes.add(null);
  }
}

class _Transaction with _Writes implements Transaction {
  _Transaction(this.store);
  @override
  final MemoryFirestore store;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async =>
      _Snapshot(
            reference as DocumentReference<Map<String, dynamic>>,
            store.documents[reference.path],
          )
          as DocumentSnapshot<T>;
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    updateDoc(reference, data);
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    setDoc(reference, data);
    return this;
  }
}

class _Batch with _Writes implements WriteBatch {
  _Batch(this.store);
  @override
  final MemoryFirestore store;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void set<T>(DocumentReference<T> reference, T data, [SetOptions? options]) =>
      setDoc(reference, data);
  @override
  Future<void> commit() async {
    if (store.failBatch) throw StateError('simulated batch failure');
    super.commit();
  }
}
