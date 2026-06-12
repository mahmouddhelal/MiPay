from fastapi import HTTPException


class AppError(HTTPException):
    """Raises an error in the standard {error: {code, message}} envelope."""

    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(
            status_code=status_code,
            detail={"error": {"code": code, "message": message}},
        )
