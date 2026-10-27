abstract class TimeDomainSource {
  DateTime now();
}

class SystemTimeDomainSource implements TimeDomainSource {
  const SystemTimeDomainSource();

  @override
  DateTime now() => DateTime.now();
}

class DeterministicTimeDomainSource implements TimeDomainSource {
  final DateTime fixedDateTime;

  const DeterministicTimeDomainSource(this.fixedDateTime);

  @override
  DateTime now() => fixedDateTime;
}
