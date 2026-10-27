import 'migration_dto.dart';

/// Pure stateless transformation layer for field values using lightweight DTOs.
class MigrationService {
  /// Performs stateless value transformations (e.g. whitespace trimming) on a list of fields.
  static List<MigrationFieldOutput> migrateFields(
    List<MigrationFieldInput> fields,
  ) {
    return fields.map((f) {
      // Clean and sanitize string values by trimming leading and trailing whitespaces
      final trimmedValue = f.valueText?.trim();
      return MigrationFieldOutput(
        fieldKey: f.fieldKey,
        valueText: trimmedValue,
        fieldNote: f.fieldNote,
      );
    }).toList();
  }
}
