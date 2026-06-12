from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.config import settings

# NullPool: pooled asyncpg connections bind to the event loop that created them,
# which breaks under pytest-asyncio's per-test loops. Connection churn is
# negligible at MVP scale.
engine = create_async_engine(settings.DATABASE_URL, echo=False, poolclass=NullPool)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session
