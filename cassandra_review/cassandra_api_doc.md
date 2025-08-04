CREATE KEYSPACE IF NOT EXISTS fantasy_game
    WITH REPLICATION = {
        'class': 'NetworkTopologyStrategy',
        'datacenter1': 3
        }
     AND DURABLE_WRITES = TRUE;

## Cluster Diagram
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                FANTASY_GAME_CLUSTER                                       │
│                                   (datacenter1)                                          │
│                                                                                           │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │     NODE 1          │  │     NODE 2          │  │     NODE 3          │               │
│  │   (rack1)           │  │   (rack2)           │  │   (rack3)           │               │
│  │                     │  │                     │  │                     │               │
│  │ Port: 9042          │  │ Port: 9043          │  │ Port: 9044          │               │
│  │ JMX: 7199           │  │ JMX: 7200           │  │ JMX: 7201           │               │
│  │                     │  │                     │  │                     │               │
│  │ 16 virtual nodes    │  │ 16 virtual nodes    │  │ 16 virtual nodes    │               │
│  │ (vnodes)            │  │ (vnodes)            │  │ (vnodes)            │               │
│  │                     │  │                     │  │                     │               │
│  │ Token Ranges:       │  │ Token Ranges:       │  │ Token Ranges:       │               │
│  │ -9223...to...       │  │ -3074...to...       │  │ 3074...to...        │               │
│  │ -3074...            │  │ 3074...             │  │ 9223...             │               │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘               │
└─────────────────────────────────────────────────────────────────────────────────────────┘


USE fantasy_game;


## Endpoint
**POST** `/api/user/session`
**POST** `/api/user/{guid}/preferences`
**GET** `/api/user/{guid}/profile`

CREATE TABLE IF NOT EXISTS users (
    partition_id smallint,
    user_id bigint,
    source_id text,
    user_guid uuid,
    first_name text,
    last_name text,
    user_name text,
    device_id smallint,
    device_version text,
    login_platform_source smallint,
    profanity_status smallint,
    preferences_saved boolean,
    user_properties text,
    user_preferences text,
    opt_in text,
    created_date timestamp,
    updated_date timestamp,
    registered_date timestamp,
    PRIMARY KEY (partition_id, user_id)
) WITH COMMENT = 'Users partitioned by source_id hash, clustered by user_id';

CREATE TABLE IF NOT EXISTS users_by_source (
    partition_id smallint,
    source_id text,
    user_id bigint,
    user_guid uuid,
    login_platform_source smallint,
    created_date timestamp,
    PRIMARY KEY (partition_id, source_id)
) WITH COMMENT = 'Lookup table for source_id to user_id mapping for authentication';

-- Partition calculation logic (implement in application layer):
-- partition_id = hash(source_id) % 10

┌─────────────────────────────────────────────────────────────────┐
│                PARTITION DISTRIBUTION (10 partitions)           │
│                                                                 │
│  Partition 0: hash("fb_123456") % 10 = 0                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ user_id: 1001, source_id: "fb_123456"                   │    │
│  │ user_id: 1045, source_id: "fb_789012"                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Partition 1: hash("google_987654") % 10 = 1                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ user_id: 1002, source_id: "google_987654"              │   │
│  │ user_id: 1078, source_id: "google_456789"              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ... (partitions 2-9 similarly distributed)                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PARTITION TO NODE MAPPING                    │
│                                                                 │
│  Your 10 partitions (0-9) are distributed across 3 nodes:       │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   NODE 1    │  │   NODE 2    │  │   NODE 3    │              │
│  │   (rack1)   │  │   (rack2)   │  │   (rack3)   │              │
│  │             │  │             │  │             │              │
│  │ Partitions: │  │ Partitions: │  │ Partitions: │              │
│  │ 0, 3, 6, 9  │  │ 1, 4, 7     │  │ 2, 5, 8     │              │
│  │             │  │             │  │             │              │
│  │ (Primary    │  │ (Primary    │  │ (Primary    │              │
│  │  replicas)  │  │  replicas)  │  │  replicas)  │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                 │
│  But with RF=3, each partition is replicated to ALL nodes!      │
└─────────────────────────────────────────────────────────────────┘

Key Concept: You Can Connect to ANY Node
Answer: NO, you don't need to pre-determine which node to use. Any node can act as a coordinator for any query.


-- Insert sample user (partition_id calculated as hash(source_id) % 10)
-- Assuming "1234567890" hashes to partition 3

-- Main table
INSERT INTO users (
    partition_id, user_id, source_id, user_guid, first_name, last_name,
    user_name, device_id, device_version, login_platform_source,
    profanity_status, preferences_saved, user_properties, user_preferences,
    opt_in, created_date, updated_date, registered_date
) VALUES (
    3, 1001, '1234567890', a5a74150-364f-4a2a-baab-e4a5d37835ea,
    'Shreyas', 'Shreyas', 'Shreyas(urlencode)', 1, '1.0',
    1, 1, true,
    '[{"key":"residence_country","value":"IN"},{"key":"subscription_active","value":"1"}]',
    '[{"preference":"country","value":1},{"preference":"team_1","value":1}]',
    '{"email":true,"sms":false}',
    '2025-01-29T07:06:36.000Z', '2025-01-29T07:06:36.000Z', '2025-01-29T07:06:36.000Z'
);

-- Lookup table
INSERT INTO users_by_source (
    partition_id, source_id, user_id, user_guid, login_platform_source, created_date
) VALUES (
    3, '1234567890', 1001, a5a74150-364f-4a2a-baab-e4a5d37835ea, 1, '2025-01-29T07:06:36.000Z'
);

Data Flow Visualization:
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                               INSERT OPERATION FLOW                                      │
│                          (partition_id = 3, user_id = 1001)                              │
│                                                                                           │
│  Step 1: Client connects to NODE 2 (arbitrary choice)                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Client → NODE 2 (Coordinator)                                                  │   │
│  │ "INSERT INTO users ... partition_id=3 ..."                                     │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                           │
│  Step 2: NODE 2 calculates which nodes should store partition_id=3                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ Coordinator (NODE 2) calculates:                                               │   │
│  │ • Hash(partition_id=3) → Token: 2847294723947                                  │   │
│  │ • Primary replica: NODE 1 (owns this token range)                              │   │
│  │ • RF=3, so also replicate to: NODE 2, NODE 3                                   │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                           │
│  Step 3: NODE 2 sends writes to all replica nodes                                       │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                 │   │
│  │  NODE 2 (Coordinator) sends parallel writes:                                   │   │
│  │  ├─ NODE 1: Write partition_id=3 data ✓                                       │   │
│  │  ├─ NODE 2: Write partition_id=3 data ✓ (local write)                         │   │
│  │  └─ NODE 3: Write partition_id=3 data ✓                                       │   │
│  │                                                                                 │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                           │
│  Step 4: Wait for consistency level acknowledgments                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │ With QUORUM consistency (default):                                             │   │
│  │ • Wait for 2 out of 3 nodes to acknowledge                                     │   │
│  │ • Once 2 nodes confirm, return success to client                               │   │
│  │ • Third node write continues in background                                     │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Where Is Your Data Actually Stored?
With your keyspace configuration (RF=3), every piece of data is stored on ALL 3 nodes:
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              DATA REPLICATION (RF=3)                                     │
│                                                                                           │
│  User Record: partition_id=3, user_id=1001, source_id='fb_123456'                       │
│                                                                                           │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐               │
│  │     NODE 1          │  │     NODE 2          │  │     NODE 3          │               │
│  │    (rack1)          │  │    (rack2)          │  │    (rack3)          │               │
│  │                     │  │                     │  │                     │               │
│  │ ┌─────────────────┐ │  │ ┌─────────────────┐ │  │ ┌─────────────────┐ │               │
│  │ │   REPLICA 1     │ │  │ │   REPLICA 2     │ │  │ │   REPLICA 3     │ │               │
│  │ │                 │ │  │ │                 │ │  │ │                 │ │               │
│  │ │ partition_id: 3 │ │  │ │ partition_id: 3 │ │  │ │ partition_id: 3 │ │               │
│  │ │ user_id: 1001   │ │  │ │ user_id: 1001   │ │  │ │ user_id: 1001   │ │               │
│  │ │ source_id: fb_  │ │  │ │ source_id: fb_  │ │  │ │ source_id: fb_  │ │               │
│  │ │ first_name: John│ │  │ │ first_name: John│ │  │ │ first_name: John│ │               │
│  │ │ ...             │ │  │ │ ...             │ │  │ │ ...             │ │               │
│  │ └─────────────────┘ │  │ └─────────────────┘ │  │ └─────────────────┘ │               │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘               │
│                                                                                           │
│  Result: Data survives failure of ANY 1 node                                            │
│  Query can be served from ANY of the 3 nodes                                            │
└─────────────────────────────────────────────────────────────────────────────────────────┘


## Endpoint
**POST** `/api/user/{guid}/save-team`
**POST** `/api/user/{guid}/transfers`
**POST** `/api/user/{guid}/substitutions`
**GET** `/api/user/{guid}/gameset/{gameset_id}/user-teams`

CREATE TABLE IF NOT EXISTS user_teams_latest (
    partition_id smallint,
    user_bucket smallint,
    user_id bigint,
    team_no smallint,

    -- Current gameset info
    current_gameset_id smallint,
    current_gameday_id smallint,
    -- Team basic info
    team_name text,
    upper_team_name text,
    profanity_status smallint,
    profanity_updated_date timestamp,
    -- Current team composition
    team_valuation decimal,
    remaining_budget decimal,
    captain_player_id int,
    vice_captain_player_id int,
    inplay_entities text,        -- JSON: [{"entity_id":1,"skill_id":1,"order":1}...]
    reserved_entities text,      -- JSON: [{"entity_id":12,"skill_id":1,"order":1}...]
    -- Booster info
    booster_id smallint,
    booster_player_id int,
    booster_team_players text,   -- JSON: [entity_ids]
    -- Transfer/substitution tracking
    transfers_allowed smallint,
    transfers_made smallint,
    transfers_left smallint,
    substitution_allowed smallint,
    substitution_made smallint,
    substitution_left smallint,
    -- Performance data
    total_points decimal,
    current_rank int,
    -- Metadata
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id, user_bucket), user_id, team_no)
) WITH COMMENT = 'Latest team state for fast current gameset queries';

CREATE TABLE IF NOT EXISTS user_team_details (
    partition_id smallint,
    user_bucket smallint,
    user_id bigint,
    season_id smallint,
    team_no smallint,
    gameset_id smallint,
    gameday_id smallint,
    -- Gameset validity period
    from_gameset_id smallint,
    from_gameday_id smallint,
    to_gameset_id smallint,
    to_gameday_id smallint,
    -- Team composition for this gameset
    team_valuation decimal,
    remaining_budget decimal,
    captain_player_id int,
    vice_captain_player_id int,
    inplay_entities text,        -- Complete team JSON for this gameset
    reserved_entities text,
    team_formation text,         -- JSON: formation breakdown
    -- Booster info
    booster_id smallint,
    booster_player_id int,
    booster_team_players text,
    -- Transfer tracking for this gameset
    transfers_allowed smallint,
    transfers_made smallint,
    transfers_left smallint,
    substitution_allowed smallint,
    substitution_made smallint,
    substitution_left smallint,
    -- Performance for this gameset
    gameset_points decimal,
    gameset_rank int,
    -- Metadata
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id, user_bucket, gameset_id), user_id, team_no, gameday_id)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, gameday_id DESC)
AND COMMENT = 'Historical team states by gameset for time-travel queries';

CREATE TABLE IF NOT EXISTS user_team_transfers (
    partition_id smallint,
    user_bucket smallint,
    user_id bigint,
    season_id smallint,
    team_no smallint,
    transfer_id uuid,
    gameset_id smallint,
    gameday_id smallint,
    -- Transfer operation details
    action_type text,            -- 'CREATE', 'TRANSFER', 'SUBSTITUTE'
    booster_id smallint,
    booster_player_id int,
    -- Player movements
    entities_in text,            -- JSON: [{"entity_id":13,"skill_id":1,"order":1}...]
    entities_out text,           -- JSON: [{"entity_id":12,"skill_id":1,"order":1}...]
    original_team_players text,  -- JSON: full team before change
    new_team_players text,       -- JSON: full team after change
    -- Transfer metadata
    transfers_made smallint,
    transfer_cost decimal,
    transfer_metadata text,      -- JSON: additional data for analytics
    -- Metadata
    device_id smallint,
    created_date timestamp,
    updated_date timestamp,
    PRIMARY KEY ((partition_id, user_bucket, gameset_id), user_id, team_no, transfer_id)
) WITH CLUSTERING ORDER BY (user_id ASC, team_no ASC, transfer_id DESC)
AND COMMENT = 'Complete audit trail for transfers, substitutions, and analytics';

-- For CURRENT gameset (fastest path)
SELECT user_id, team_no, team_name, profanity_status,
       current_gameset_id, team_valuation, remaining_budget,
       captain_player_id, vice_captain_player_id,
       inplay_entities, reserved_entities,
       booster_id, booster_player_id,
       transfers_allowed, transfers_made, transfers_left,
       total_points, current_rank
FROM user_teams_latest 
WHERE partition_id = ? AND user_id = ?;

-- For HISTORICAL gameset (when gameset_id != current_gameset_id)
SELECT user_id, team_no, gameset_id, inplay_entities, gameset_points
FROM user_team_details 
WHERE partition_id = ? AND user_bucket = ? AND gameset_id = ?
  AND user_id = ?;



