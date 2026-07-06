from decimal import Decimal

from pydantic import BaseModel


class CategorySummary(BaseModel):
    category: str
    total: Decimal
    count: int


class SummaryOut(BaseModel):
    month: str
    currency: str
    total_income: Decimal
    total_expense: Decimal
    balance: Decimal
    by_category: list[CategorySummary]
    by_category_income: list[CategorySummary] = []
