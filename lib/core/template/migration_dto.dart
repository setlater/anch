import 'package:meta/meta.dart';

/// Type-safe migration DTO mapping input field values.
@immutable
class MigrationFieldInput {
  final String fieldKey;
  final String? valueText;
  final String? fieldNote;

  const MigrationFieldInput({
    required this.fieldKey,
    this.valueText,
    this.fieldNote,
  });
}

/// Type-safe migration DTO mapping output field values.
@immutable
class MigrationFieldOutput {
  final String fieldKey;
  final String? valueText;
  final String? fieldNote;

  const MigrationFieldOutput({
    required this.fieldKey,
    this.valueText,
    this.fieldNote,
  });
}

/// Pure stateless Isolate item input payload.
@immutable
class MigrationIsolateItemInput {
  final String id;
  final String typeKey;
  final List<MigrationFieldInput> fields;

  const MigrationIsolateItemInput({
    required this.id,
    required this.typeKey,
    required this.fields,
  });
}

/// Pure stateless Isolate input container.
@immutable
class MigrationIsolateInput {
  final List<MigrationIsolateItemInput> items;

  const MigrationIsolateInput({required this.items});
}

/// Pure stateless Isolate item output payload.
@immutable
class MigrationIsolateItemOutput {
  final String id;
  final List<MigrationFieldOutput> fields;

  const MigrationIsolateItemOutput({required this.id, required this.fields});
}
