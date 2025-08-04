-- ====================================================================
-- CASSANDRA MIGRATION: MASTER DATA TABLES
-- ====================================================================
-- This file contains master/configuration data tables optimized for Cassandra
-- These tables handle relatively static data with infrequent updates

-- Sports and Skills Configuration
-- Query Pattern: Lookup by sport_id for skills, lookup all sports
CREATE TABLE sports (
    sport_id smallint,
    sport_name text,
    created_at timestamp,
    PRIMARY KEY (sport_id)
) WITH COMMENT = 'Master table for sports - static data, query by sport_id';

CREATE TABLE sport_skills (
    sport_id smallint,
    skill_id smallint,
    skill_name text,
    skill_short_name text,
    feed_skill_id smallint,
    PRIMARY KEY (sport_id, skill_id)
) WITH COMMENT = 'Skills by sport - partitioned by sport_id for efficient skill lookups';

-- Device and Platform Configuration (Small static tables)
CREATE TABLE devices (
    device_id smallint,
    device_name text,
    PRIMARY KEY (device_id)
) WITH COMMENT = 'Device types - very small static table';

CREATE TABLE platforms (
    platform_id smallint,
    platform_name text,
    PRIMARY KEY (platform_id)
) WITH COMMENT = 'Platform types - very small static table';

-- Game Configuration
CREATE TABLE game_variants (
    variant_id smallint,
    variant_name text,
    PRIMARY KEY (variant_id)
) WITH COMMENT = 'Game variants - static lookup table';

CREATE TABLE chip_types (
    chip_id smallint,
    chip_name text,
    chip_type text,
    multiplier decimal,
    PRIMARY KEY (chip_id)
) WITH COMMENT = 'Chip types for boosters - static configuration';

-- Applications and Seasons
-- Query Pattern: Lookup application by id, get seasons by application_id
CREATE TABLE applications (
    application_id smallint,
    application_name text,
    admin_id smallint,
    sport_id smallint,
    variant_id smallint,
    created_date timestamp,
    updated_date timestamp,
    logo_url text,
    config_json text, -- JSON as text in Cassandra
    PRIMARY KEY (application_id)
) WITH COMMENT = 'Applications - lookup by application_id';

-- Seasons partitioned by application for efficient queries
CREATE TABLE seasons (
    application_id smallint,
    season_id smallint,
    season_name text,
    created_date timestamp,
    updated_date timestamp,
    device_ids set<smallint>,
    status_id smallint,
    is_enabled_for_operator boolean,
    PRIMARY KEY (application_id, season_id)
) WITH COMMENT = 'Seasons by application - enables efficient season lookup per app';

-- Season Configuration (Denormalized from multiple PostgreSQL tables)
CREATE TABLE season_configurations (
    season_id smallint,
    config_type text, -- 'budget', 'chip', 'team', 'transfer', etc.
    config_id text,   -- unique identifier for this config
    config_data text, -- JSON configuration data
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY (season_id, config_type, config_id)
) WITH COMMENT = 'Denormalized season configs - all season settings in one table';

-- Countries (Small static table)
CREATE TABLE countries (
    country_id smallint,
    country_name text,
    country_code text,
    PRIMARY KEY (country_id)
) WITH COMMENT = 'Countries lookup table';

-- Response Types and Status Tables (Small static tables)
CREATE TABLE response_types (
    response_code smallint,
    response_desc text,
    PRIMARY KEY (response_code)
) WITH COMMENT = 'Response code lookup table';

CREATE TABLE season_statuses (
    status_id smallint,
    status text,
    PRIMARY KEY (status_id)
) WITH COMMENT = 'Season status lookup table';

CREATE TABLE profanity_statuses (
    status_id smallint,
    status text,
    PRIMARY KEY (status_id)
) WITH COMMENT = 'Profanity status lookup table';

-- Admin Users (Small table)
CREATE TABLE admin_users (
    user_id smallint,
    user_name text,
    display_user_name text,
    user_password text,
    status smallint,
    created_date timestamp,
    is_super_admin boolean,
    PRIMARY KEY (user_id)
) WITH COMMENT = 'Admin users - small lookup table';

-- Create a secondary index for username lookup
CREATE INDEX ON admin_users (user_name);

-- Language Configuration
CREATE TABLE languages (
    season_id smallint,
    language_code text,
    language_name text,
    is_deleted boolean,
    PRIMARY KEY (season_id, language_code)
) WITH COMMENT = 'Languages by season - partitioned for efficient season queries';

-- Team Constraints (Configuration)
CREATE TABLE team_constraints (
    constraint_id smallint,
    constraint_type_id smallint,
    constraint_type text,
    constraint_subtype_id smallint,
    constraint_subtype text,
    PRIMARY KEY (constraint_id)
) WITH COMMENT = 'Team constraint definitions - static configuration';

-- Application Database Configuration
CREATE TABLE application_databases (
    application_id smallint,
    database_id smallint,
    database_type text,
    shard_id smallint,
    connection_details text,
    PRIMARY KEY (application_id, database_id)
) WITH COMMENT = 'Database configuration by application'; 