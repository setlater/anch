import 'package:meta/meta.dart';
import '../../../core/field/field_origin.dart';

@immutable
class FieldState {
  final String value;
  final FieldOrigin origin;

  const FieldState({required this.value, required this.origin});

  FieldState copyWith({String? value, FieldOrigin? origin}) {
    return FieldState(
      value: value ?? this.value,
      origin: origin ?? this.origin,
    );
  }
}
