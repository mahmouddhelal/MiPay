from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import CurrentUser
from app.db.session import get_db
from app.models.category import Category
from app.schemas.category import CategoryOut

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryOut])
async def list_categories(
    current_user: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[CategoryOut]:
    result = await db.execute(select(Category).order_by(Category.sort_order))
    return [CategoryOut.model_validate(c) for c in result.scalars().all()]
