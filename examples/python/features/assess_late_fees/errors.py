class RecordProblem(Exception):
    """A problem with one record that should stop that record, not the run.
    The context catches only these; anything else is a bug and propagates."""


class UnrecognizedDeposit(RecordProblem):
    pass


class NoticeFailed(Exception):
    """Raised by a late-fee notice port that could not deliver."""


class ImpossibleRun(Exception):
    """Raised when a run's results are impossible; something upstream is wrong."""
