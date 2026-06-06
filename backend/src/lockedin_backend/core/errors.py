class BackendError(Exception):
    """Base application error."""


class ConflictError(BackendError):
    """Raised when a resource already exists or conflicts."""


class NotFoundError(BackendError):
    """Raised when a requested resource does not exist."""
