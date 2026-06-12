import re
import uuid
from dataclasses import asdict
from datetime import date as date_type
from typing import Literal

from fastapi import APIRouter, Depends, Form, Query, Request, UploadFile
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUser
from app.core.exceptions import AppError
from app.db.session import get_db
from app.models.transaction import Transaction
from app.schemas.transaction import (
    ExtractTextRequest,
    TransactionCreate,
    TransactionListOut,
    TransactionOut,
    TransactionUpdate,
    VoiceExtractionResult,
)
from app.services import voice_pipeline
from app.services.extraction import ExtractionError
from app.services.stt import STTService
from app.services.voice_pipeline import PipelineResult

router = APIRouter(prefix="/transactions", tags=["transactions"])

_MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


def _month_range(month: str) -> tuple[date_type, date_type]:
    """'2026-06' -> (2026-06-01, 2026-07-01) half-open interval."""
    year, mon = int(month[:4]), int(month[5:7])
    start = date_type(year, mon, 1)
    end = date_type(year + 1, 1, 1) if mon == 12 else date_type(year, mon + 1, 1)
    return start, end


async def _get_owned_transaction(
    transaction_id: uuid.UUID, user_id: uuid.UUID, db: AsyncSession
) -> Transaction:
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id,
            Transaction.user_id == user_id,
        )
    )
    tx = result.scalar_one_or_none()
    if tx is None:
        raise AppError(404, "NOT_FOUND", "Transaction not found.")
    return tx


def _to_response(result: PipelineResult) -> VoiceExtractionResult:
    return VoiceExtractionResult(
        status=result.status,
        transcript=result.transcript,
        detected_language=result.detected_language,
        extraction=asdict(result.extraction) if result.extraction else None,
        timing_ms=result.timing_ms,
    )


@router.post("/voice", response_model=VoiceExtractionResult)
async def extract_from_voice(
    request: Request,
    current_user: CurrentUser,
    audio: UploadFile,
    client_date: date_type = Form(...),
    client_locale: Literal["ar", "en"] = Form("en"),
) -> VoiceExtractionResult:
    """The AI endpoint (§5.2). Returns the extraction — saves nothing.
    The app saves via POST /transactions after user confirmation."""
    stt: STTService | None = getattr(request.app.state, "whisper_model", None)
    if stt is None:
        raise AppError(503, "STT_UNAVAILABLE", "Speech model is not loaded yet.")

    try:
        result = await voice_pipeline.process_audio(
            audio, client_date, current_user.default_currency, stt
        )
    except ExtractionError:
        raise AppError(502, "EXTRACTION_FAILED", "The extraction service is unavailable.")
    return _to_response(result)


@router.post("/extract-text", response_model=VoiceExtractionResult)
async def extract_from_text(
    body: ExtractTextRequest,
    current_user: CurrentUser,
) -> VoiceExtractionResult:
    """Mode B (FEATURES.md §2): typed input — same pipeline, no STT step."""
    try:
        result = await voice_pipeline.process_text(
            body.text, body.client_date, current_user.default_currency
        )
    except ExtractionError:
        raise AppError(502, "EXTRACTION_FAILED", "The extraction service is unavailable.")
    return _to_response(result)


@router.post("", response_model=TransactionOut, status_code=201)
async def create_transaction(
    body: TransactionCreate,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransactionOut:
    tx = Transaction(user_id=current_user.id, **body.model_dump())
    db.add(tx)
    await db.commit()
    await db.refresh(tx)
    return TransactionOut.model_validate(tx)


@router.get("", response_model=TransactionListOut)
async def list_transactions(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    month: str | None = Query(default=None, description="YYYY-MM"),
    category: str | None = None,
    type: Literal["expense", "income"] | None = None,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> TransactionListOut:
    filters = [Transaction.user_id == current_user.id]

    if month is not None:
        if not _MONTH_RE.match(month):
            raise AppError(422, "VALIDATION_ERROR", "month must be in YYYY-MM format.")
        start, end = _month_range(month)
        filters.append(Transaction.date >= start)
        filters.append(Transaction.date < end)
    if category is not None:
        filters.append(Transaction.category == category)
    if type is not None:
        filters.append(Transaction.transaction_type == type)

    total = (
        await db.execute(select(func.count()).select_from(Transaction).where(*filters))
    ).scalar_one()

    result = await db.execute(
        select(Transaction)
        .where(*filters)
        .order_by(Transaction.date.desc(), Transaction.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    items = result.scalars().all()

    return TransactionListOut(
        items=[TransactionOut.model_validate(t) for t in items],
        page=page,
        page_size=page_size,
        total=total,
    )


@router.get("/{transaction_id}", response_model=TransactionOut)
async def get_transaction(
    transaction_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransactionOut:
    tx = await _get_owned_transaction(transaction_id, current_user.id, db)
    return TransactionOut.model_validate(tx)


@router.patch("/{transaction_id}", response_model=TransactionOut)
async def update_transaction(
    transaction_id: uuid.UUID,
    body: TransactionUpdate,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransactionOut:
    tx = await _get_owned_transaction(transaction_id, current_user.id, db)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(tx, field, value)
    await db.commit()
    await db.refresh(tx)
    return TransactionOut.model_validate(tx)


@router.delete("/{transaction_id}", status_code=204)
async def delete_transaction(
    transaction_id: uuid.UUID,
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    tx = await _get_owned_transaction(transaction_id, current_user.id, db)
    await db.delete(tx)
    await db.commit()
