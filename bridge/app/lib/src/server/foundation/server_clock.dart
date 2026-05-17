class ServerClock {
  const ServerClock();

  DateTime now() {
    return DateTime.now().toUtc();
  }

  Future<void> delay({required Duration duration}) {
    return Future<void>.delayed(duration);
  }
}
