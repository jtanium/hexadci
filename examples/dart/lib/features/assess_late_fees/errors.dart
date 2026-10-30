// Dart already separates the two kinds of failure this feature cares about:
// an `Exception` is a problem with the world (bad data, a service that is
// down), and an `Error` is a bug. The context catches only RecordProblem;
// Errors always propagate.

/// A problem with one record that should stop that record, not the run.
class RecordProblem implements Exception {
  final String message;

  RecordProblem(this.message);

  @override
  String toString() => message;
}

class UnrecognizedDeposit extends RecordProblem {
  UnrecognizedDeposit(super.message);
}

/// Thrown by a late-fee notice port that could not deliver.
class NoticeFailed implements Exception {
  final String message;

  NoticeFailed(this.message);

  @override
  String toString() => message;
}

/// Thrown when a run's results are impossible; something upstream is wrong.
class ImpossibleRun extends StateError {
  ImpossibleRun(super.message);
}
