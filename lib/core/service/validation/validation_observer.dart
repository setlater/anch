import 'field_validation_error.dart';

/// A passive event sink for validation results.
abstract class ValidationObserver {
  void onValidationResult(ValidationResult result, {required String typeKey});
}
