"""create books"""
from alembic import op
import sqlalchemy as sa

revision = "0002_create_books"
down_revision = "0001_create_users"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "book",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("author", sa.String(length=150), nullable=False),
        sa.Column("category", sa.String(length=80), nullable=False),
        sa.Column("cover_image", sa.String(length=255), nullable=False),
        sa.Column("price", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("total_quantity", sa.Integer(), nullable=False),
        sa.Column("available_quantity", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade():
    op.drop_table("book")
