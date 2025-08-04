CREATE TABLE IF NOT EXISTS point_calculation.entity_stat
(
    sport_id         SMALLINT    NOT NULL,
    stat_id          SMALLINT    NOT NULL,
    stat_name        VARCHAR(50) NOT NULL,
    calculation_type VARCHAR(50) NOT NULL,
    CONSTRAINT entity_stat_pk
        PRIMARY KEY (sport_id, stat_id)
); 