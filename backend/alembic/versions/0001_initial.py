"""initial schema and category seed

Revision ID: 0001
Revises:
Create Date: 2026-06-12
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# All 17 categories from §4.3 enum
_CATEGORIES = [
    ("groceries",       "Groceries",        "بقالة",              "shopping_cart",    "expense", 1),
    ("restaurants",     "Restaurants",      "مطاعم",              "restaurant",       "expense", 2),
    ("transport",       "Transport",        "مواصلات",            "directions_car",   "expense", 3),
    ("fuel",            "Fuel",             "وقود",               "local_gas_station","expense", 4),
    ("shopping",        "Shopping",         "تسوق",               "shopping_bag",     "expense", 5),
    ("bills",           "Bills",            "فواتير",             "receipt_long",     "expense", 6),
    ("rent",            "Rent",             "إيجار",              "home",             "expense", 7),
    ("health",          "Health",           "صحة",                "local_hospital",   "expense", 8),
    ("education",       "Education",        "تعليم",              "school",           "expense", 9),
    ("entertainment",   "Entertainment",    "ترفيه",              "movie",            "expense", 10),
    ("travel",          "Travel",           "سفر",                "flight",           "expense", 11),
    ("personal_care",   "Personal Care",    "العناية الشخصية",    "face",             "expense", 12),
    ("gifts_donations", "Gifts & Donations","هدايا وتبرعات",      "card_giftcard",    "expense", 13),
    ("salary",          "Salary",           "راتب",               "payments",         "income",  14),
    ("business",        "Business",         "أعمال",              "business_center",  "income",  15),
    ("transfer_in",     "Transfer In",      "حوالة واردة",        "arrow_downward",   "income",  16),
    ("other",           "Other",            "أخرى",               "more_horiz",       "both",    17),
]


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.UUID, primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("display_name", sa.String(100), nullable=False),
        sa.Column("default_currency", sa.String(3), nullable=False, server_default="SAR"),
        sa.Column("locale", sa.String(5), nullable=False, server_default="en"),
        sa.Column("token_version", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("NOW()"),
            nullable=False,
        ),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "categories",
        sa.Column("key", sa.String(50), primary_key=True),
        sa.Column("label_en", sa.String(100), nullable=False),
        sa.Column("label_ar", sa.String(100), nullable=False),
        sa.Column("icon", sa.String(50), nullable=False),
        sa.Column("kind", sa.String(10), nullable=False),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
    )

    op.bulk_insert(
        sa.table(
            "categories",
            sa.column("key", sa.String),
            sa.column("label_en", sa.String),
            sa.column("label_ar", sa.String),
            sa.column("icon", sa.String),
            sa.column("kind", sa.String),
            sa.column("sort_order", sa.Integer),
        ),
        [
            {
                "key": key,
                "label_en": label_en,
                "label_ar": label_ar,
                "icon": icon,
                "kind": kind,
                "sort_order": order,
            }
            for key, label_en, label_ar, icon, kind, order in _CATEGORIES
        ],
    )


def downgrade() -> None:
    op.drop_table("categories")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
