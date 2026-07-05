"""Egyptian category labels, 12 new categories, EGP as default currency

Revision ID: 0003
Revises: 0002
Create Date: 2026-07-05

SAR→EGP update targets only rows where default_currency='SAR', which was the
untouched old server default — not a user choice. Deliberate USD/EUR/etc picks
are left as-is. Documented here so future devs understand the intent.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Egyptian-friendly rewrites for the original 17 labels
_UPDATED_LABELS = [
    ("groceries",       "بقالة وسوبرماركت"),
    ("restaurants",     "مطاعم وأكل برة"),
    ("transport",       "مواصلات"),
    ("fuel",            "بنزين"),
    ("shopping",        "شوبينج"),
    ("bills",           "فواتير"),
    ("rent",            "إيجار"),
    ("health",          "صحة وأدوية"),
    ("education",       "تعليم"),
    ("entertainment",   "خروجات وترفيه"),
    ("travel",          "سفر"),
    ("personal_care",   "العناية الشخصية"),
    ("gifts_donations", "هدايا وصدقة"),
    ("salary",          "المرتب"),
    ("business",        "أعمال"),
    ("transfer_in",     "فلوس جاتلي"),
    ("other",           "حاجات تانية"),
]

# 12 new Egypt-relevant categories
_NEW_CATEGORIES = [
    ("coffee",          "Coffee & Cafés",           "قهوة وكافيهات",          "local_cafe",       "expense", 18),
    ("internet_mobile", "Internet & Mobile",        "نت وموبايل",             "wifi",             "expense", 19),
    ("subscriptions",   "Subscriptions",            "اشتراكات",               "subscriptions",    "expense", 20),
    ("household",       "Home & Family",            "مصاريف البيت والعيلة",   "family_restroom",  "expense", 21),
    ("tuition",         "Private Lessons",          "دروس خصوصية",            "menu_book",        "expense", 22),
    ("clothes",         "Clothes",                  "هدوم ولبس",              "checkroom",        "expense", 23),
    ("pets",            "Pets",                     "حيوانات أليفة",          "pets",             "expense", 24),
    ("insurance",       "Insurance",                "تأمين",                  "shield",           "expense", 25),
    ("savings",         "Savings & Gam'eya",        "توفير وجمعية",           "savings",          "both",    26),
    ("transfer_out",    "Transfer Out",             "فلوس باعتها",            "arrow_upward",     "expense", 27),
    ("freelance",       "Freelance",                "شغل فريلانس",            "laptop_mac",       "income",  28),
    ("investments",     "Investments",              "استثمارات",              "trending_up",      "both",    29),
]


def upgrade() -> None:
    conn = op.get_bind()

    # Update existing 17 category Arabic labels to Egyptian-friendly versions
    for key, label_ar in _UPDATED_LABELS:
        conn.execute(
            sa.text("UPDATE categories SET label_ar = :label WHERE key = :key"),
            {"label": label_ar, "key": key},
        )

    # Push "other" to the end
    conn.execute(sa.text("UPDATE categories SET sort_order = 99 WHERE key = 'other'"))

    # Insert 12 new categories
    categories_table = sa.table(
        "categories",
        sa.column("key", sa.String),
        sa.column("label_en", sa.String),
        sa.column("label_ar", sa.String),
        sa.column("icon", sa.String),
        sa.column("kind", sa.String),
        sa.column("sort_order", sa.Integer),
    )
    op.bulk_insert(
        categories_table,
        [
            {"key": k, "label_en": en, "label_ar": ar, "icon": icon, "kind": kind, "sort_order": order}
            for k, en, ar, icon, kind, order in _NEW_CATEGORIES
        ],
    )

    # Change users.default_currency server default to EGP
    op.alter_column(
        "users",
        "default_currency",
        server_default="EGP",
        existing_type=sa.String(3),
        existing_nullable=False,
    )

    # Flip SAR rows — these are untouched old defaults, not user choices
    conn.execute(
        sa.text("UPDATE users SET default_currency = 'EGP' WHERE default_currency = 'SAR'")
    )


def downgrade() -> None:
    conn = op.get_bind()

    # Remove new categories
    new_keys = [k for k, *_ in _NEW_CATEGORIES]
    conn.execute(
        sa.text(f"DELETE FROM categories WHERE key IN ({','.join([':k'+str(i) for i in range(len(new_keys))])})" ),
        {f"k{i}": k for i, k in enumerate(new_keys)},
    )

    # Restore original Arabic labels
    _ORIGINAL_LABELS = [
        ("groceries",       "بقالة"),
        ("restaurants",     "مطاعم"),
        ("transport",       "مواصلات"),
        ("fuel",            "وقود"),
        ("shopping",        "تسوق"),
        ("bills",           "فواتير"),
        ("rent",            "إيجار"),
        ("health",          "صحة"),
        ("education",       "تعليم"),
        ("entertainment",   "ترفيه"),
        ("travel",          "سفر"),
        ("personal_care",   "العناية الشخصية"),
        ("gifts_donations", "هدايا وتبرعات"),
        ("salary",          "راتب"),
        ("business",        "أعمال"),
        ("transfer_in",     "حوالة واردة"),
        ("other",           "أخرى"),
    ]
    for key, label_ar in _ORIGINAL_LABELS:
        conn.execute(
            sa.text("UPDATE categories SET label_ar = :label WHERE key = :key"),
            {"label": label_ar, "key": key},
        )
    conn.execute(sa.text("UPDATE categories SET sort_order = 17 WHERE key = 'other'"))

    op.alter_column(
        "users",
        "default_currency",
        server_default="SAR",
        existing_type=sa.String(3),
        existing_nullable=False,
    )
    conn.execute(
        sa.text("UPDATE users SET default_currency = 'SAR' WHERE default_currency = 'EGP'")
    )
