import '../validation/validation_observer.dart';

/// ExecutionContext is the extensible container for future cross-cutting concerns
/// (telemetries, logging, contexts, feature flags) passed on UseCase executions.
class ExecutionContext {
  final ValidationObserver? observer;
  final Map<String, Object?> metadata;

  const ExecutionContext({this.observer, this.metadata = const {}});
}
