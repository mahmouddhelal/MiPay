"""transactions table

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-12
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # create_type=False stops create_table from emitting a second CREATE TYPE
    transaction_type = postgresql.ENUM(
        "expense", "income", name="transaction_type", create_type=False
    )
    transaction_source = postgresql.ENUM(
        "voice", "manual", name="transaction_source", create_type=False
    )
    transaction_type.create(op.get_bind(), checkfirst=True)
    transaction_source.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "transactions",
        sa.Column("id", sa.UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "user_id",
            sa.UUID,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("transaction_type", transaction_type, nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("category", sa.String(50), sa.ForeignKey("categories.key"), nullable=False),
        sa.Column("name", sa.String(200), nullable=True),
        sa.Column("date", sa.Date, nullable=False),
        sa.Column("note", sa.Text, nullable=True),
        sa.Column("source", transaction_source, nullable=False, server_default="manual"),
        sa.Column("transcript", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )

    op.create_index("ix_transactions_user_date", "transactions", ["user_id", sa.text("date DESC")])
    op.create_index("ix_transactions_user_category", "transactions", ["user_id", "category"])


def downgrade() -> None:
    op.drop_index("ix_transactions_user_category", table_name="transactions")
    op.drop_index("ix_transactions_user_date", table_name="transactions")
    op.drop_table("transactions")
    sa.Enum(name="transaction_source").drop(op.get_bind())
    sa.Enum(name="transaction_type").drop(op.get_bind())
