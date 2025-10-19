"""add failure_reason and idempotency_key to entry

Revision ID: 0002_entry_failure_idempotency
Revises: 0001_initial
Create Date: 2025-10-19
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = '0002_entry_failure_idempotency'
down_revision = '0001_initial'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('entry', sa.Column('failure_reason', sa.Text(), nullable=True))
    op.add_column('entry', sa.Column('idempotency_key', sa.String(length=255), nullable=True))
    op.create_index('ix_entry_idempotency_key', 'entry', ['idempotency_key'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_entry_idempotency_key', table_name='entry')
    op.drop_column('entry', 'idempotency_key')
    op.drop_column('entry', 'failure_reason')

