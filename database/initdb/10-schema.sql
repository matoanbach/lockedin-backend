CREATE TABLE IF NOT EXISTS profiles (
    id VARCHAR(36) NOT NULL,
    slug VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    is_demo BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_profiles PRIMARY KEY (id),
    CONSTRAINT uq_profiles_slug UNIQUE (slug)
);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_demo BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS preferences (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    has_completed_onboarding BOOLEAN NOT NULL,
    default_daily_limit_minutes INTEGER NOT NULL,
    notification_tone VARCHAR(32) NOT NULL,
    text_size_percent INTEGER NOT NULL,
    high_contrast BOOLEAN NOT NULL,
    large_tap_targets BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_preferences PRIMARY KEY (id),
    CONSTRAINT fk_preferences_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_preferences_profile_id UNIQUE (profile_id)
);

CREATE TABLE IF NOT EXISTS rules (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    app_id VARCHAR(255) NOT NULL,
    app_name VARCHAR(255) NOT NULL,
    limit_minutes INTEGER NOT NULL,
    enabled BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_rules PRIMARY KEY (id),
    CONSTRAINT fk_rules_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_rules_profile_app UNIQUE (profile_id, app_id)
);

CREATE TABLE IF NOT EXISTS accountability_contacts (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    consent_confirmed BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_accountability_contacts PRIMARY KEY (id),
    CONSTRAINT fk_accountability_contacts_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_accountability_contacts_profile_email UNIQUE (profile_id, email)
);

CREATE TABLE IF NOT EXISTS usage_events (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    app_id VARCHAR(255) NOT NULL,
    app_name VARCHAR(255) NOT NULL,
    category VARCHAR(100) NOT NULL,
    source_event_id VARCHAR(255) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL,
    timezone VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_usage_events PRIMARY KEY (id),
    CONSTRAINT fk_usage_events_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_usage_events_profile_source_event UNIQUE (profile_id, source_event_id)
);

CREATE INDEX IF NOT EXISTS ix_usage_events_profile_started_at
    ON usage_events (profile_id, started_at);

CREATE TABLE IF NOT EXISTS usage_daily_app_aggregates (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    usage_date DATE NOT NULL,
    app_id VARCHAR(255) NOT NULL,
    app_name VARCHAR(255) NOT NULL,
    total_minutes INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_usage_daily_app_aggregates PRIMARY KEY (id),
    CONSTRAINT fk_usage_daily_app_aggregates_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_usage_daily_app_aggregates_profile_date_app UNIQUE (profile_id, usage_date, app_id)
);

CREATE INDEX IF NOT EXISTS ix_usage_daily_app_aggregates_profile_usage_date
    ON usage_daily_app_aggregates (profile_id, usage_date);

CREATE TABLE IF NOT EXISTS usage_daily_category_aggregates (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    usage_date DATE NOT NULL,
    category VARCHAR(100) NOT NULL,
    total_minutes INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_usage_daily_category_aggregates PRIMARY KEY (id),
    CONSTRAINT fk_usage_daily_category_aggregates_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_usage_daily_category_aggregates_profile_date_category UNIQUE (profile_id, usage_date, category)
);

CREATE INDEX IF NOT EXISTS ix_usage_daily_category_aggregates_profile_usage_date
    ON usage_daily_category_aggregates (profile_id, usage_date);

CREATE TABLE IF NOT EXISTS enforcement_events (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    rule_id VARCHAR(36),
    app_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(64) NOT NULL,
    usage_date DATE NOT NULL,
    used_minutes INTEGER NOT NULL,
    limit_minutes INTEGER NOT NULL,
    metadata_json TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_enforcement_events PRIMARY KEY (id),
    CONSTRAINT fk_enforcement_events_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_enforcement_events_rule_id_rules FOREIGN KEY (rule_id)
        REFERENCES rules (id)
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS ix_enforcement_events_profile_usage_date
    ON enforcement_events (profile_id, usage_date);

CREATE INDEX IF NOT EXISTS ix_enforcement_events_profile_rule_created_at
    ON enforcement_events (profile_id, rule_id, created_at);

CREATE TABLE IF NOT EXISTS accounts (
    id VARCHAR(36) NOT NULL,
    profile_id VARCHAR(36) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    tokens_valid_after TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_accounts PRIMARY KEY (id),
    CONSTRAINT fk_accounts_profile_id_profiles FOREIGN KEY (profile_id)
        REFERENCES profiles (id)
        ON DELETE RESTRICT,
    CONSTRAINT uq_accounts_profile_id UNIQUE (profile_id)
);

CREATE TABLE IF NOT EXISTS external_identities (
    id VARCHAR(36) NOT NULL,
    account_id VARCHAR(36) NOT NULL,
    issuer VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_external_identities PRIMARY KEY (id),
    CONSTRAINT fk_external_identities_account_id_accounts FOREIGN KEY (account_id)
        REFERENCES accounts (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_external_identities_issuer_subject UNIQUE (issuer, subject)
);

CREATE TABLE IF NOT EXISTS revoked_provider_sessions (
    id VARCHAR(36) NOT NULL,
    account_id VARCHAR(36) NOT NULL,
    issuer VARCHAR(255) NOT NULL,
    sid VARCHAR(255) NOT NULL,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT pk_revoked_provider_sessions PRIMARY KEY (id),
    CONSTRAINT fk_revoked_provider_sessions_account_id_accounts FOREIGN KEY (account_id)
        REFERENCES accounts (id)
        ON DELETE CASCADE,
    CONSTRAINT uq_revoked_provider_sessions_issuer_sid UNIQUE (issuer, sid),
    CONSTRAINT ck_revoked_provider_sessions_expires_not_before_revocation
        CHECK (expires_at >= revoked_at)
);

CREATE OR REPLACE FUNCTION lockdin_assert_account_profile_ownable()
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_accounts_profile_ownable ON accounts;
CREATE TRIGGER trg_accounts_profile_ownable
BEFORE INSERT OR UPDATE OF profile_id ON accounts
FOR EACH ROW EXECUTE FUNCTION lockdin_assert_account_profile_ownable();

CREATE OR REPLACE FUNCTION lockdin_prevent_owned_demo_profile()
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_prevent_owned_demo ON profiles;
CREATE TRIGGER trg_profiles_prevent_owned_demo
BEFORE UPDATE OF is_demo ON profiles
FOR EACH ROW EXECUTE FUNCTION lockdin_prevent_owned_demo_profile();
