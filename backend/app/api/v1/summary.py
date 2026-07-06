import re
from datetime import date as date_type
from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUser
from app.core.exceptions import AppError
from app.db.session import get_db
from app.models.transaction import Transaction
from app.schemas.summary import CategorySummary, SummaryOut

router = APIRouter(prefix="/summary", tags=["summary"])

_MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


@router.get("", response_model=SummaryOut)
async def get_summary(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
    month: str = Query(..., description="YYYY-MM"),
) -> SummaryOut:
    """Monthly summary: income, expense, balance, per-category expense breakdown."""
    if not _MONTH_RE.match(month):
        raise AppError(422, "VALIDATION_ERROR", "month must be in YYYY-MM format.")

    year, mon = int(month[:4]), int(month[5:7])
    start = date_type(year, mon, 1)
    end = date_type(year + 1, 1, 1) if mon == 12 else date_type(year, mon + 1, 1)

    base_filter = [
        Transaction.user_id == current_user.id,
        Transaction.date >= start,
        Transaction.date < end,
    ]

    agg = await db.execute(
        select(
            func.coalesce(
                func.sum(
                    case(
                        (Transaction.transaction_type == "income", Transaction.amount),
                        else_=Decimal("0"),
                    )
                ),
                Decimal("0"),
            ).label("total_income"),
            func.coalesce(
                func.sum(
                    case(
                        (Transaction.transaction_type == "expense", Transaction.amount),
                        else_=Decimal("0"),
                    )
                ),
                Decimal("0"),
            ).label("total_expense"),
        ).where(*base_filter)
    )
    row = agg.one()
    total_income: Decimal = row.total_income
    total_expense: Decimal = row.total_expense

    async def _category_breakdown(transaction_type: str) -> list[CategorySummary]:
        rows = await db.execute(
            select(
                Transaction.category,
                func.sum(Transaction.amount).label("total"),
                func.count(Transaction.id).label("count"),
            )
            .where(*base_filter, Transaction.transaction_type == transaction_type)
            .group_by(Transaction.category)
            .order_by(func.sum(Transaction.amount).desc())
        )
        return [
            CategorySummary(category=r.category, total=r.total, count=r.count)
            for r in rows.all()
        ]

    by_category_expense = await _category_breakdown("expense")
    by_category_income = await _category_breakdown("income")

    return SummaryOut(
        month=month,
        currency=current_user.default_currency,
        total_income=total_income,
        total_expense=total_expense,
        balance=total_income - total_expense,
        by_category=by_category_expense,
        by_category_income=by_category_income,
    )
