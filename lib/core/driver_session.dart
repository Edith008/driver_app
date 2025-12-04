class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.username,
  });

  final int id;
  final String name;
  final String username;
}

class DriverSession {
  DriverSession._internal();

  static final DriverSession instance = DriverSession._internal();

  DriverProfile? _current;

  DriverProfile? get driver => _current;

  bool get isLoggedIn => _current != null;

  void setDriver(DriverProfile driver) {
    _current = driver;
  }

  void clear() {
    _current = null;
  }
}
