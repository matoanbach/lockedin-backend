"""Add the guarded tenant and identity foundation.

Revision ID: 20260803_01
Revises: None
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect, text


revision = "20260803_01"
down_revision = None
branch_labels = None
depends_on = None


LEGACY_COLUMNS = {
    "profiles": {"id", "slug", "name", "created_at", "updated_at"},
    "preferences": {
        "id", "profile_id", "has_completed_onboarding",
        "default_daily_limit_minutes", "notification_tone", "text_size_percent",
        "high_contrast", "large_tap_targets", "created_at", "updated_at",
    },
    "rules": {
        "id", "profile_id", "app_id", "app_name", "limit_minutes", "enabled",
        "created_at", "updated_at",
    },
    "accountability_contacts": {
        "id", "profile_id", "name", "email", "consent_confirmed",
        "created_at", "updated_at",
    },
    "usage_events": {
        "id", "profile_id", "app_id", "app_name", "category", "source_event_id",
        "started_at", "ended_at", "duration_minutes", "timezone", "created_at",
        "updated_at",
    },
    "usage_daily_app_aggregates": {
        "id", "profile_id", "usage_date", "app_id", "app_name", "total_minutes",
        "created_at", "updated_at",
    },
    "usage_daily_category_aggregates": {
        "id", "profile_id", "usage_date", "category", "total_minutes", "created_at",
        "updated_at",
    },
    "enforcement_events": {
        "id", "profile_id", "rule_id", "app_id", "event_type", "usage_date",
        "used_minutes", "limit_minutes", "metadata_json", "created_at", "updated_at",
    },
}

REQUIRED_UNIQUES = {
    "profiles": {"uq_profiles_slug": ("slug",)},
    "preferences": {"uq_preferences_profile_id": ("profile_id",)},
    "rules": {"uq_rules_profile_app": ("profile_id", "app_id")},
    "accountability_contacts": {
        "uq_accountability_contacts_profile_email": ("profile_id", "email")
    },
    "usage_events": {
        "uq_usage_events_profile_source_event": ("profile_id", "source_event_id")
    },
    "usage_daily_app_aggregates": {
        "uq_usage_daily_app_aggregates_profile_date_app": (
            "profile_id", "usage_date", "app_id",
        )
    },
    "usage_daily_category_aggregates": {
        "uq_usage_daily_category_aggregates_profile_date_category": (
            "profile_id", "usage_date", "category",
        )
    },
}

STRING_LENGTHS = {
    "profiles": {"id": 36, "slug": 50, "name": 100},
    "preferences": {"id": 36, "profile_id": 36, "notification_tone": 32},
    "rules": {
        "id": 36, "profile_id": 36, "app_id": 255, "app_name": 255,
    },
    "accountability_contacts": {
        "id": 36, "profile_id": 36, "name": 255, "email": 255,
    },
    "usage_events": {
        "id": 36, "profile_id": 36, "app_id": 255, "app_name": 255,
        "category": 100, "source_event_id": 255, "timezone": 100,
    },
    "usage_daily_app_aggregates": {
        "id": 36, "profile_id": 36, "app_id": 255, "app_name": 255,
    },
    "usage_daily_category_aggregates": {
        "id": 36, "profile_id": 36, "category": 100,
    },
    "enforcement_events": {
        "id": 36, "profile_id": 36, "rule_id": 36, "app_id": 255,
        "event_type": 64,
    },
}

BOOLEAN_COLUMNS = {
    "preferences": {
        "has_completed_onboarding", "high_contrast", "large_tap_targets",
    },
    "rules": {"enabled"},
    "accountability_contacts": {"consent_confirmed"},
}
INTEGER_COLUMNS = {
    "preferences": {"default_daily_limit_minutes", "text_size_percent"},
    "rules": {"limit_minutes"},
    "usage_events": {"duration_minutes"},
    "usage_daily_app_aggregates": {"total_minutes"},
    "usage_daily_category_aggregates": {"total_minutes"},
    "enforcement_events": {"used_minutes", "limit_minutes"},
}
DATE_COLUMNS = {
    "usage_daily_app_aggregates": {"usage_date"},
    "usage_daily_category_aggregates": {"usage_date"},
    "enforcement_events": {"usage_date"},
}
TIMESTAMP_COLUMNS = {
    table_name: {"created_at", "updated_at"} for table_name in LEGACY_COLUMNS
}
TIMESTAMP_COLUMNS["usage_events"] |= {"started_at", "ended_at"}
TEXT_COLUMNS = {"enforcement_events": {"metadata_json"}}

REQUIRED_FOREIGN_KEYS = {
    "preferences": {
        "fk_preferences_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        )
    },
    "rules": {
        "fk_rules_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        )
    },
    "accountability_contacts": {
        "fk_accountability_contacts_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        )
    },
    "usage_events": {
        "fk_usage_events_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        )
    },
    "usage_daily_app_aggregates": {
        "fk_usage_daily_app_aggregates_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        )
    },
    "usage_daily_category_aggregates": {
        "fk_usage_daily_category_aggregates_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        )
    },
    "enforcement_events": {
        "fk_enforcement_events_profile_id_profiles": (
            ("profile_id",), "profiles", ("id",), "CASCADE",
        ),
        "fk_enforcement_events_rule_id_rules": (
            ("rule_id",), "rules", ("id",), "SET NULL",
        ),
    },
}

REQUIRED_INDEXES = {
    "usage_events": {
        "ix_usage_events_profile_started_at": ("profile_id", "started_at")
    },
    "usage_daily_app_aggregates": {
        "ix_usage_daily_app_aggregates_profile_usage_date": (
            "profile_id", "usage_date",
        )
    },
    "usage_daily_category_aggregates": {
        "ix_usage_daily_category_aggregates_profile_usage_date": (
            "profile_id", "usage_date",
        )
    },
    "enforcement_events": {
        "ix_enforcement_events_profile_usage_date": ("profile_id", "usage_date"),
        "ix_enforcement_events_profile_rule_created_at": (
            "profile_id", "rule_id", "created_at",
        ),
    },
}


def _timestamp_columns() -> list[sa.Column]:
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    ]


def _create_legacy_schema() -> None:
    op.create_table(
        "profiles",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("slug", sa.String(50), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        *_timestamp_columns(),
        sa.PrimaryKeyConstraint("id", name="pk_profiles"),
        sa.UniqueConstraint("slug", name="uq_profiles_slug"),
    )
    op.create_table(
        "preferences",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("has_completed_onboarding", sa.Boolean(), nullable=False),
        sa.Column("default_daily_limit_minutes", sa.Integer(), nullable=False),
        sa.Column("notification_tone", sa.String(32), nullable=False),
        sa.Column("text_size_percent", sa.Integer(), nullable=False),
        sa.Column("high_contrast", sa.Boolean(), nullable=False),
        sa.Column("large_tap_targets", sa.Boolean(), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"], name="fk_preferences_profile_id_profiles",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_preferences"),
        sa.UniqueConstraint("profile_id", name="uq_preferences_profile_id"),
    )
    op.create_table(
        "rules",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("app_id", sa.String(255), nullable=False),
        sa.Column("app_name", sa.String(255), nullable=False),
        sa.Column("limit_minutes", sa.Integer(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"], name="fk_rules_profile_id_profiles",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_rules"),
        sa.UniqueConstraint("profile_id", "app_id", name="uq_rules_profile_app"),
    )
    op.create_table(
        "accountability_contacts",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("consent_confirmed", sa.Boolean(), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"],
            name="fk_accountability_contacts_profile_id_profiles", ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_accountability_contacts"),
        sa.UniqueConstraint(
            "profile_id", "email", name="uq_accountability_contacts_profile_email"
        ),
    )
    op.create_table(
        "usage_events",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("app_id", sa.String(255), nullable=False),
        sa.Column("app_name", sa.String(255), nullable=False),
        sa.Column("category", sa.String(100), nullable=False),
        sa.Column("source_event_id", sa.String(255), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=False),
        sa.Column("timezone", sa.String(100), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"], name="fk_usage_events_profile_id_profiles",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_usage_events"),
        sa.UniqueConstraint(
            "profile_id", "source_event_id", name="uq_usage_events_profile_source_event"
        ),
    )
    op.create_index(
        "ix_usage_events_profile_started_at", "usage_events", ["profile_id", "started_at"]
    )
    op.create_table(
        "usage_daily_app_aggregates",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("app_id", sa.String(255), nullable=False),
        sa.Column("app_name", sa.String(255), nullable=False),
        sa.Column("total_minutes", sa.Integer(), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"],
            name="fk_usage_daily_app_aggregates_profile_id_profiles", ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_usage_daily_app_aggregates"),
        sa.UniqueConstraint(
            "profile_id", "usage_date", "app_id",
            name="uq_usage_daily_app_aggregates_profile_date_app",
        ),
    )
    op.create_index(
        "ix_usage_daily_app_aggregates_profile_usage_date",
        "usage_daily_app_aggregates", ["profile_id", "usage_date"],
    )
    op.create_table(
        "usage_daily_category_aggregates",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("category", sa.String(100), nullable=False),
        sa.Column("total_minutes", sa.Integer(), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"],
            name="fk_usage_daily_category_aggregates_profile_id_profiles",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_usage_daily_category_aggregates"),
        sa.UniqueConstraint(
            "profile_id", "usage_date", "category",
            name="uq_usage_daily_category_aggregates_profile_date_category",
        ),
    )
    op.create_index(
        "ix_usage_daily_category_aggregates_profile_usage_date",
        "usage_daily_category_aggregates", ["profile_id", "usage_date"],
    )
    op.create_table(
        "enforcement_events",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("rule_id", sa.String(36), nullable=True),
        sa.Column("app_id", sa.String(255), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("usage_date", sa.Date(), nullable=False),
        sa.Column("used_minutes", sa.Integer(), nullable=False),
        sa.Column("limit_minutes", sa.Integer(), nullable=False),
        sa.Column("metadata_json", sa.Text(), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"],
            name="fk_enforcement_events_profile_id_profiles", ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["rule_id"], ["rules.id"], name="fk_enforcement_events_rule_id_rules",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_enforcement_events"),
    )
    op.create_index(
        "ix_enforcement_events_profile_usage_date", "enforcement_events",
        ["profile_id", "usage_date"],
    )
    op.create_index(
        "ix_enforcement_events_profile_rule_created_at", "enforcement_events",
        ["profile_id", "rule_id", "created_at"],
    )


def _verify_legacy_schema() -> None:
    inspector = inspect(op.get_bind())
    present = set(inspector.get_table_names()) - {"alembic_version"}
    expected = set(LEGACY_COLUMNS)
    if present != expected:
        raise RuntimeError(
            "Unversioned database is not the exact LockdIn legacy schema; "
            f"expected tables {sorted(expected)}, found {sorted(present)}"
        )
    for table_name, expected_columns in LEGACY_COLUMNS.items():
        inspected_columns = inspector.get_columns(table_name)
        actual_columns = {column["name"] for column in inspected_columns}
        if actual_columns != expected_columns:
            raise RuntimeError(
                f"Legacy table {table_name!r} has unexpected columns: "
                f"expected {sorted(expected_columns)}, found {sorted(actual_columns)}"
            )
        for column in inspected_columns:
            column_name = column["name"]
            expected_nullable = column_name == "rule_id"
            if bool(column["nullable"]) != expected_nullable:
                raise RuntimeError(
                    f"Legacy column {table_name}.{column_name} has unexpected nullability"
                )
            actual_type = column["type"]
            expected_length = STRING_LENGTHS.get(table_name, {}).get(column_name)
            valid_type = False
            if expected_length is not None:
                valid_type = isinstance(actual_type, sa.String) and (
                    actual_type.length == expected_length
                )
            elif column_name in BOOLEAN_COLUMNS.get(table_name, set()):
                valid_type = isinstance(actual_type, sa.Boolean)
            elif column_name in INTEGER_COLUMNS.get(table_name, set()):
                valid_type = isinstance(actual_type, sa.Integer)
            elif column_name in DATE_COLUMNS.get(table_name, set()):
                valid_type = isinstance(actual_type, sa.Date) and not isinstance(
                    actual_type, sa.DateTime
                )
            elif column_name in TIMESTAMP_COLUMNS.get(table_name, set()):
                valid_type = isinstance(actual_type, sa.DateTime) and bool(
                    actual_type.timezone
                )
            elif column_name in TEXT_COLUMNS.get(table_name, set()):
                valid_type = isinstance(actual_type, sa.Text)
            if not valid_type:
                raise RuntimeError(
                    f"Legacy column {table_name}.{column_name} has unexpected type "
                    f"{actual_type!s}"
                )
        primary_key = inspector.get_pk_constraint(table_name)
        if (
            primary_key.get("name") != f"pk_{table_name}"
            or tuple(primary_key.get("constrained_columns") or ()) != ("id",)
        ):
            raise RuntimeError(f"Legacy table {table_name!r} has an unexpected primary key")
        uniques = {
            constraint.get("name"): tuple(constraint.get("column_names") or ())
            for constraint in inspector.get_unique_constraints(table_name)
        }
        expected_uniques = REQUIRED_UNIQUES.get(table_name, {})
        if uniques != expected_uniques:
            raise RuntimeError(f"Legacy table {table_name!r} has unexpected uniqueness")
        foreign_keys = {
            constraint.get("name"): (
                tuple(constraint.get("constrained_columns") or ()),
                constraint.get("referred_table"),
                tuple(constraint.get("referred_columns") or ()),
                str((constraint.get("options") or {}).get("ondelete") or "").upper(),
            )
            for constraint in inspector.get_foreign_keys(table_name)
        }
        if foreign_keys != REQUIRED_FOREIGN_KEYS.get(table_name, {}):
            raise RuntimeError(f"Legacy table {table_name!r} has unexpected foreign keys")
        indexes = {
            index.get("name"): tuple(index.get("column_names") or ())
            for index in inspector.get_indexes(table_name)
            if (
                not index.get("duplicates_constraint")
                and index.get("name") not in uniques
                and not index.get("unique")
            )
        }
        if indexes != REQUIRED_INDEXES.get(table_name, {}):
            raise RuntimeError(f"Legacy table {table_name!r} has unexpected indexes")


def _add_tenant_foundation() -> None:
    op.add_column(
        "profiles",
        sa.Column("is_demo", sa.Boolean(), server_default=sa.false(), nullable=False),
    )
    op.add_column(
        "profiles",
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
    )

    bind = op.get_bind()
    fixed = bind.execute(
        text("SELECT slug FROM profiles WHERE id = :id"),
        {"id": "00000000-0000-0000-0000-000000000001"},
    ).scalar_one_or_none()
    if fixed is not None and fixed != "default":
        raise RuntimeError("The fixed demo profile ID belongs to a non-default profile")
    bind.execute(
        text("UPDATE profiles SET is_demo = TRUE WHERE slug = 'default'")
    )

    op.create_table(
        "accounts",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("profile_id", sa.String(36), nullable=False),
        sa.Column("enabled", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column(
            "tokens_valid_after", sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False,
        ),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["profile_id"], ["profiles.id"], name="fk_accounts_profile_id_profiles",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_accounts"),
        sa.UniqueConstraint("profile_id", name="uq_accounts_profile_id"),
    )
    op.create_table(
        "external_identities",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("account_id", sa.String(36), nullable=False),
        sa.Column("issuer", sa.String(255), nullable=False),
        sa.Column("subject", sa.String(255), nullable=False),
        *_timestamp_columns(),
        sa.ForeignKeyConstraint(
            ["account_id"], ["accounts.id"],
            name="fk_external_identities_account_id_accounts", ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_external_identities"),
        sa.UniqueConstraint(
            "issuer", "subject", name="uq_external_identities_issuer_subject"
        ),
    )
    op.create_table(
        "revoked_provider_sessions",
        sa.Column("id", sa.String(36), nullable=False),
        sa.Column("account_id", sa.String(36), nullable=False),
        sa.Column("issuer", sa.String(255), nullable=False),
        sa.Column("sid", sa.String(255), nullable=False),
        sa.Column(
            "revoked_at", sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False,
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        *_timestamp_columns(),
        sa.CheckConstraint(
            "expires_at >= revoked_at",
            name="expires_not_before_revocation",
        ),
        sa.ForeignKeyConstraint(
            ["account_id"], ["accounts.id"],
            name="fk_revoked_provider_sessions_account_id_accounts", ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_revoked_provider_sessions"),
        sa.UniqueConstraint(
            "issuer", "sid", name="uq_revoked_provider_sessions_issuer_sid"
        ),
    )

    op.execute("""
        CREATE FUNCTION lockdin_assert_account_profile_ownable()
        RETURNS trigger AS $$
        DECLARE
            profile_is_demo BOOLEAN;
        BEGIN
            SELECT is_demo INTO profile_is_demo
            FROM profiles
            WHERE id = NEW.profile_id
            FOR UPDATE;
            IF profile_is_demo THEN
                RAISE EXCEPTION 'demo profiles cannot be owned by accounts'
                    USING ERRCODE = '23514';
            END IF;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE TRIGGER trg_accounts_profile_ownable
        BEFORE INSERT OR UPDATE OF profile_id ON accounts
        FOR EACH ROW EXECUTE FUNCTION lockdin_assert_account_profile_ownable()
    """)
    op.execute("""
        CREATE FUNCTION lockdin_prevent_owned_demo_profile()
        RETURNS trigger AS $$
        BEGIN
            IF NEW.is_demo AND EXISTS (
                SELECT 1 FROM accounts WHERE profile_id = NEW.id
            ) THEN
                RAISE EXCEPTION 'owned profiles cannot become demo profiles'
                    USING ERRCODE = '23514';
            END IF;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE TRIGGER trg_profiles_prevent_owned_demo
        BEFORE UPDATE OF is_demo ON profiles
        FOR EACH ROW EXECUTE FUNCTION lockdin_prevent_owned_demo_profile()
    """)


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        raise RuntimeError("LockdIn migrations require PostgreSQL")
    inspector = inspect(op.get_bind())
    present = set(inspector.get_table_names()) - {"alembic_version"}
    if not present:
        _create_legacy_schema()
    else:
        _verify_legacy_schema()
    _add_tenant_foundation()


def downgrade() -> None:
    raise RuntimeError(
        "Destructive downgrade is unsupported; roll back the application and retain "
        "the additive tenant-foundation schema"
    )
