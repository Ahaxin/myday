"""initial schema

Revision ID: 0001_initial
Revises: 
Create Date: 2025-10-19
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'user',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('email', sa.String(), nullable=False, unique=True),
        sa.Column('apple_sub', sa.String(), nullable=True, unique=True),
        sa.Column('google_sub', sa.String(), nullable=True, unique=True),
        sa.Column('created_at', sa.DateTime(timezone=False), nullable=False),
    )
    op.create_index('ix_user_email', 'user', ['email'], unique=True)
    op.create_index('ix_user_apple_sub', 'user', ['apple_sub'], unique=True)
    op.create_index('ix_user_google_sub', 'user', ['google_sub'], unique=True)

    op.create_table(
        'entry',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('user.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=False), nullable=False),
        sa.Column('duration_s', sa.Integer(), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('audio_url', sa.String(), nullable=True),
        sa.Column('size_bytes', sa.Integer(), nullable=True),
        sa.Column('language', sa.String(), nullable=True),
        sa.Column('transcript_raw', sa.Text(), nullable=True),
        sa.Column('transcript_clean', sa.Text(), nullable=True),
    )
    op.create_index('ix_entry_user_id_created_at', 'entry', ['user_id', 'created_at'])

    op.create_table(
        'exportrequest',
        sa.Column('id', sa.Integer(), primary_key=True, nullable=False),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('user.id'), nullable=False),
        sa.Column('date_from', sa.DateTime(timezone=False), nullable=False),
        sa.Column('date_to', sa.DateTime(timezone=False), nullable=False),
        sa.Column('status', sa.String(), nullable=False),
        sa.Column('result_url', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=False), nullable=False),
    )
    op.create_index('ix_export_user_id_date', 'exportrequest', ['user_id', 'date_from', 'date_to'])


def downgrade() -> None:
    op.drop_index('ix_export_user_id_date', table_name='exportrequest')
    op.drop_table('exportrequest')

    op.drop_index('ix_entry_user_id_created_at', table_name='entry')
    op.drop_table('entry')

    op.drop_index('ix_user_google_sub', table_name='user')
    op.drop_index('ix_user_apple_sub', table_name='user')
    op.drop_index('ix_user_email', table_name='user')
    op.drop_table('user')

