-- This file is executed only by PostgreSQL's empty-data-directory initialization sequence.
-- It records that 10-schema.sql is the snapshot for the guarded Phase B migration head.
CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL,
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

INSERT INTO alembic_version (version_num) VALUES ('20260808_02');
