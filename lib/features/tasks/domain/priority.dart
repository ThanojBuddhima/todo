enum Priority {
  low(0),
  medium(1),
  high(2);

  const Priority(this.value);

  final int value;

  static Priority fromValue(int value) => switch (value) {
    0 => Priority.low,
    2 => Priority.high,
    _ => Priority.medium,
  };
}
