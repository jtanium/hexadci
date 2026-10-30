module AssessLateFees
  # A problem with one record that should stop that record, not the run.
  # The context catches only these; anything else is a bug and propagates.
  class RecordProblem < StandardError; end

  class UnrecognizedDeposit < RecordProblem; end

  # Raised by a late-fee notice port that could not deliver.
  class NoticeFailed < StandardError; end

  # Raised when a run's results are impossible; something upstream is wrong.
  class ImpossibleRun < StandardError; end
end
