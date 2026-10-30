/**
 * A problem with one record that should stop that record, not the run.
 * The context catches only these; anything else is a bug and propagates.
 */
export class RecordProblem extends Error {
  override name = "RecordProblem";
}

export class UnrecognizedDeposit extends RecordProblem {
  override name = "UnrecognizedDeposit";
}

/** Thrown by a late-fee notice port that could not deliver. */
export class NoticeFailed extends Error {
  override name = "NoticeFailed";
}

/** Thrown when a run's results are impossible; something upstream is wrong. */
export class ImpossibleRun extends Error {
  override name = "ImpossibleRun";
}
