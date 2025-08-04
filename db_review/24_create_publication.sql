-- Creates a publication on the admin shard for tables that need to be replicated.
-- The publication name is passed as a variable :pub_name

DROP PUBLICATION IF EXISTS :"pub_name";

CREATE PUBLICATION :"pub_name" FOR TABLE
    engine_config.application,
    engine_config.application_budget_configuration,
    engine_config.application_chip_configuration,
    engine_config.application_database,
    engine_config.application_maintenance,
    engine_config.application_user_team_configuration,
    engine_config.application_user_team_constraint_configuration,
    engine_config.application_user_team_misc_configuration,
    engine_config.application_user_team_skill_configuration,
    engine_config.application_user_team_transfer_configuration,
    engine_config.season,
    engine_config.season_config,
    game_management.fixture,
    game_management.gameday,
    game_management.gameset,
    game_management.phase,
    game_management.player,
    game_management.team,
    game_management.venue,
    gameplay.gameset_player,
    league.league_type; 