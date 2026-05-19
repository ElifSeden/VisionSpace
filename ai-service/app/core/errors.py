class AppError(Exception):
    pass


class ValidationStageError(AppError):
    pass


class AIOutputValidationError(AppError):
    pass


class ProductRetrievalError(AppError):
    pass


class PlacementValidationError(AppError):
    pass


class ImageStorageError(AppError):
    pass

