/// Source of the current time, injectable so tests can pin "now".
class AppClock {
  const AppClock([this._now = DateTime.now]);

  final DateTime Function() _now;

  DateTime now() => _now();
}
