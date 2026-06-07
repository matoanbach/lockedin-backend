INSERT INTO profiles (id, slug, name, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'default',
    'Development Profile',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO preferences (
    id,
    profile_id,
    has_completed_onboarding,
    default_daily_limit_minutes,
    notification_tone,
    text_size_percent,
    high_contrast,
    large_tap_targets,
    created_at,
    updated_at
)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    TRUE,
    180,
    'professional',
    100,
    FALSE,
    FALSE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
)
ON CONFLICT (profile_id) DO NOTHING;

INSERT INTO rules (id, profile_id, app_id, app_name, limit_minutes, enabled, created_at, updated_at)
VALUES
    (
        '00000000-0000-0000-0000-000000000101',
        '00000000-0000-0000-0000-000000000001',
        'com.instagram.android',
        'Instagram',
        90,
        TRUE,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ),
    (
        '00000000-0000-0000-0000-000000000102',
        '00000000-0000-0000-0000-000000000001',
        'com.google.android.youtube',
        'YouTube',
        45,
        TRUE,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ),
    (
        '00000000-0000-0000-0000-000000000103',
        '00000000-0000-0000-0000-000000000001',
        'com.spotify.music',
        'Spotify',
        60,
        TRUE,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
ON CONFLICT ON CONSTRAINT uq_rules_profile_app DO NOTHING;

INSERT INTO accountability_contacts (
    id,
    profile_id,
    name,
    email,
    consent_confirmed,
    created_at,
    updated_at
)
VALUES (
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000001',
    'Demo Accountability Partner',
    'partner@example.com',
    TRUE,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
)
ON CONFLICT ON CONSTRAINT uq_accountability_contacts_profile_email DO NOTHING;

WITH base AS (
    SELECT (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date AS local_today
), historical_events AS (
    SELECT *
    FROM (VALUES
        ('00000000-0000-0000-0000-000000000301', 'seed:instagram:day-6', 'com.instagram.android', 'Instagram', 'Social', 6, TIME '20:00', TIME '21:00', 60),
        ('00000000-0000-0000-0000-000000000302', 'seed:youtube:day-5', 'com.google.android.youtube', 'YouTube', 'Entertainment', 5, TIME '19:30', TIME '20:20', 50),
        ('00000000-0000-0000-0000-000000000303', 'seed:instagram:day-4', 'com.instagram.android', 'Instagram', 'Social', 4, TIME '21:00', TIME '22:40', 100),
        ('00000000-0000-0000-0000-000000000304', 'seed:spotify:day-3', 'com.spotify.music', 'Spotify', 'Entertainment', 3, TIME '22:00', TIME '22:45', 45),
        ('00000000-0000-0000-0000-000000000305', 'seed:instagram:day-2', 'com.instagram.android', 'Instagram', 'Social', 2, TIME '19:00', TIME '19:30', 30),
        ('00000000-0000-0000-0000-000000000306', 'seed:youtube:day-1', 'com.google.android.youtube', 'YouTube', 'Entertainment', 1, TIME '19:15', TIME '20:10', 55)
    ) AS t(id, source_event_id, app_id, app_name, category, day_offset, start_time, end_time, duration_minutes)
)
INSERT INTO usage_events (
    id,
    profile_id,
    app_id,
    app_name,
    category,
    source_event_id,
    started_at,
    ended_at,
    duration_minutes,
    timezone,
    created_at,
    updated_at
)
SELECT
    historical_events.id,
    '00000000-0000-0000-0000-000000000001',
    historical_events.app_id,
    historical_events.app_name,
    historical_events.category,
    historical_events.source_event_id,
    ((base.local_today - historical_events.day_offset)::timestamp + historical_events.start_time) AT TIME ZONE 'Asia/Ho_Chi_Minh',
    ((base.local_today - historical_events.day_offset)::timestamp + historical_events.end_time) AT TIME ZONE 'Asia/Ho_Chi_Minh',
    historical_events.duration_minutes,
    'Asia/Ho_Chi_Minh',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM base
CROSS JOIN historical_events
ON CONFLICT ON CONSTRAINT uq_usage_events_profile_source_event DO NOTHING;

INSERT INTO usage_events (
    id,
    profile_id,
    app_id,
    app_name,
    category,
    source_event_id,
    started_at,
    ended_at,
    duration_minutes,
    timezone,
    created_at,
    updated_at
)
VALUES (
    '00000000-0000-0000-0000-000000000307',
    '00000000-0000-0000-0000-000000000001',
    'com.instagram.android',
    'Instagram',
    'Social',
    'seed:instagram:today',
    CURRENT_TIMESTAMP - INTERVAL '80 minutes',
    CURRENT_TIMESTAMP - INTERVAL '20 minutes',
    60,
    'Asia/Ho_Chi_Minh',
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
)
ON CONFLICT ON CONSTRAINT uq_usage_events_profile_source_event DO NOTHING;

INSERT INTO usage_daily_app_aggregates (
    id,
    profile_id,
    usage_date,
    app_id,
    app_name,
    total_minutes,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid()::text,
    profile_id,
    (started_at AT TIME ZONE timezone)::date,
    app_id,
    app_name,
    SUM(duration_minutes)::integer,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM usage_events
WHERE profile_id = '00000000-0000-0000-0000-000000000001'
  AND source_event_id LIKE 'seed:%'
GROUP BY
    profile_id,
    (started_at AT TIME ZONE timezone)::date,
    app_id,
    app_name
ON CONFLICT ON CONSTRAINT uq_usage_daily_app_aggregates_profile_date_app DO NOTHING;

INSERT INTO usage_daily_category_aggregates (
    id,
    profile_id,
    usage_date,
    category,
    total_minutes,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid()::text,
    profile_id,
    (started_at AT TIME ZONE timezone)::date,
    category,
    SUM(duration_minutes)::integer,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
FROM usage_events
WHERE profile_id = '00000000-0000-0000-0000-000000000001'
  AND source_event_id LIKE 'seed:%'
GROUP BY
    profile_id,
    (started_at AT TIME ZONE timezone)::date,
    category
ON CONFLICT ON CONSTRAINT uq_usage_daily_category_aggregates_profile_date_category DO NOTHING;

INSERT INTO enforcement_events (
    id,
    profile_id,
    rule_id,
    app_id,
    event_type,
    usage_date,
    used_minutes,
    limit_minutes,
    metadata_json,
    created_at,
    updated_at
)
VALUES
    (
        gen_random_uuid()::text,
        '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000102',
        'com.google.android.youtube',
        'warning_approaching_limit',
        (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
        38,
        45,
        '{"source":"database_seed"}',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    ),
    (
        gen_random_uuid()::text,
        '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000102',
        'com.google.android.youtube',
        'intervention_blocked',
        (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
        52,
        45,
        '{"source":"database_seed"}',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
ON CONFLICT DO NOTHING;
