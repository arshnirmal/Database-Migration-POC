#!/usr/bin/env node

/**
 * Fantasy Game Cassandra POC Testing Script - Node.js Version
 * ===========================================================
 *
 * This script tests core fantasy game APIs against Cassandra to evaluate
 * performance compared to PostgreSQL. It includes realistic football data
 * and comprehensive performance metrics.
 *
 * Usage:
 * node fantasy-game-poc.js --users 1000 --tests 100
 */

const cassandra = require('cassandra-driver');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const path = require('path');
const { program } = require('commander');
const colors = require('colors');

// ====================================================================
// CONFIGURATION & SETUP
// ====================================================================

const CASSANDRA_CONFIG = {
    contactPoints: ['127.0.0.1:9042', '127.0.0.1:9043', '127.0.0.1:9044'],
    localDataCenter: 'datacenter1',
    keyspace: 'fantasy_game',
    socketOptions: {
        readTimeout: 20000, // 20 second read timeout
        connectTimeout: 10000 // 10 second connect timeout
    },
    queryOptions: {
        consistency: cassandra.types.consistencies.localQuorum,
        retry: {
            times: 3,
            delay: 100
        },
        prepare: true
    }
};

const DEFAULT_USERS = 1000;
const DEFAULT_TESTS = 100;
const CURRENT_SEASON = 2024;
const CURRENT_GAMESET = 15;
const CURRENT_GAMEDAY = 3;

// Performance tracking
const performanceStats = {
    userLogin: [],
    getUserProfile: [],
    saveTeam: [],
    getUserTeams: [],
    transferTeam: [],
    transferValidationErrors: [],
    errors: []
};

// ====================================================================
// ENHANCED FANTASY FOOTBALL DATA WITH PRICES & VALIDATION RULES
// ====================================================================

const FOOTBALL_PLAYERS = [
    { id: 1001, name: "Kevin De Bruyne", skillId: 2, price: 12.5, value: 12.5, team: "Man City" },
    { id: 1002, name: "Mohamed Salah", skillId: 3, price: 13.0, value: 13.0, team: "Liverpool" },
    { id: 1003, name: "Harry Kane", skillId: 4, price: 11.5, value: 11.5, team: "Bayern Munich" },
    { id: 1004, name: "Virgil van Dijk", skillId: 1, price: 6.5, value: 6.5, team: "Liverpool" },
    { id: 1005, name: "Sadio Mané", skillId: 3, price: 10.0, value: 10.0, team: "Al Nassr" },
    { id: 1006, name: "N'Golo Kanté", skillId: 2, price: 5.5, value: 5.5, team: "Al-Ittihad" },
    { id: 1007, name: "Sergio Ramos", skillId: 1, price: 5.0, value: 5.0, team: "PSG" },
    { id: 1008, name: "Luka Modrić", skillId: 2, price: 8.5, value: 8.5, team: "Real Madrid" },
    { id: 1009, name: "Robert Lewandowski", skillId: 4, price: 9.0, value: 9.0, team: "Barcelona" },
    { id: 1010, name: "Kylian Mbappé", skillId: 3, price: 12.0, value: 12.0, team: "PSG" },
    { id: 1011, name: "Alisson Becker", skillId: 5, price: 5.5, value: 5.5, team: "Liverpool" }, // Goalkeeper
    { id: 1012, name: "Mason Mount", skillId: 2, price: 6.5, value: 6.5, team: "Man United" },
    { id: 1013, name: "Phil Foden", skillId: 3, price: 8.0, value: 8.0, team: "Man City" },
    { id: 1014, name: "Bruno Fernandes", skillId: 2, price: 8.5, value: 8.5, team: "Man United" },
    { id: 1015, name: "Erling Haaland", skillId: 4, price: 15.0, value: 15.0, team: "Man City" },
    { id: 1016, name: "Thibaut Courtois", skillId: 5, price: 5.0, value: 5.0, team: "Real Madrid" }, // Goalkeeper
    { id: 1017, name: "Karim Benzema", skillId: 4, price: 10.0, value: 10.0, team: "Al-Ittihad" },
    { id: 1018, name: "Pedri", skillId: 2, price: 6.0, value: 6.0, team: "Barcelona" },
    { id: 1019, name: "Vinicius Jr.", skillId: 3, price: 9.5, value: 9.5, team: "Real Madrid" },
    { id: 1020, name: "João Cancelo", skillId: 1, price: 7.0, value: 7.0, team: "Man City" }
];

// Skill ID mapping for formation validation
const SKILL_POSITIONS = {
    1: 'DEFENDER',     // Defenders
    2: 'MIDFIELDER',   // Midfielders  
    3: 'FORWARD',      // Forwards
    4: 'STRIKER',      // Strikers
    5: 'GOALKEEPER'    // Goalkeepers
};

// Required formation constraints
const FORMATION_RULES = {
    1: { min: 3, max: 5 },  // Defenders: 3-5
    2: { min: 3, max: 5 },  // Midfielders: 3-5
    3: { min: 1, max: 3 },  // Forwards: 1-3
    4: { min: 1, max: 3 },  // Strikers: 1-3
    5: { min: 1, max: 1 }   // Goalkeepers: exactly 1
};

const TEAM_NAMES = [
    "Thunderbolts United", "Lightning Strikers", "Phoenix Rising", "Dragon Warriors",
    "Viper Squad", "Eagle Force", "Titan Crushers", "Storm Riders", "Fire Eagles",
    "Ice Wolves", "Shadow Hunters", "Golden Arrows", "Silver Bullets", "Crimson Lions",
    "Blue Sharks", "Green Machines", "Purple Panthers", "Orange Crushers", "Red Devils",
    "Black Hawks", "White Tigers", "Yellow Jackets", "Pink Flamingos", "Brown Bears"
];

const SOURCE_PLATFORMS = [
    { id: 1, name: "facebook", prefix: "fb_" },
    { id: 2, name: "google", prefix: "gg_" },
    { id: 3, name: "apple", prefix: "ap_" },
    { id: 4, name: "twitter", prefix: "tw_" }
];

const FIRST_NAMES = [
    "James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph",
    "Thomas", "Christopher", "Charles", "Daniel", "Matthew", "Anthony", "Mark",
    "Donald", "Steven", "Paul", "Andrew", "Joshua", "Kenneth", "Kevin", "Brian",
    "George", "Edward", "Ronald", "Timothy", "Jason", "Jeffrey", "Ryan", "Jacob"
];

const LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
    "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson",
    "White", "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker"
];

// ====================================================================
// CASSANDRA CONNECTION & UTILITIES
// ====================================================================

class CassandraConnection {
    constructor() {
        this.client = null;
        this.preparedStatements = new Map();
    }

    async connect() {
        try {
            this.client = new cassandra.Client(CASSANDRA_CONFIG);
            await this.client.connect();
            
            // Driver-version compatibility shim
            if (typeof this.client.prepare !== 'function') {
                this.client.prepare = async (query) => query;
                const _origExecute = this.client.execute.bind(this.client);
                this.client.execute = (query, params = [], options = {}) => {
                    if (typeof query === 'string') {
                        options = { ...options, prepare: true };
                    }
                    return _origExecute(query, params, options);
                };
            }

            console.log('✅ Connected to Cassandra cluster'.green);
            await this.prepareCQLStatements();
            return true;
        } catch (error) {
            console.error('❌ Failed to connect to Cassandra:'.red, error.message);
            return false;
        }
    }

    async prepareCQLStatements() {
        const statements = {
            // User operations
            insertUser: `
                INSERT INTO users (
                    partition_id, user_id, source_id, user_guid, first_name, last_name,
                    user_name, device_id, device_version, login_platform_source,
                    profanity_status, preferences_saved, user_properties, user_preferences,
                    opt_in, created_date, updated_date, registered_date
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,

            insertUserBySource: `
                INSERT INTO users_by_source (
                    partition_id, source_id, user_id, user_guid, login_platform_source, created_date
                ) VALUES (?, ?, ?, ?, ?, ?)`,

            getUserBySource: `
                SELECT user_id, user_guid, partition_id FROM users_by_source
                WHERE partition_id = ? AND source_id = ?`,

            getUserProfile: `
                SELECT user_id, source_id, user_guid, first_name, last_name, user_name,
                       device_id, login_platform_source, profanity_status, preferences_saved,
                       user_properties, user_preferences, created_date
                FROM users WHERE partition_id = ? AND user_id = ?`,

            // Team operations
            insertTeamLatest: `
                INSERT INTO user_teams_latest (
                    partition_id, user_bucket, user_id, team_no, current_gameset_id,
                    current_gameday_id, team_name, upper_team_name, profanity_status,
                    team_valuation, remaining_budget, captain_player_id, vice_captain_player_id,
                    inplay_entities, reserved_entities, booster_id, booster_player_id,
                    transfers_allowed, transfers_made, transfers_left,
                    total_points, current_rank, device_id, created_date, updated_date
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,

            insertTeamDetails: `
                INSERT INTO user_team_details (
                    partition_id, user_bucket, gameset_id, user_id, team_no, gameday_id,
                    from_gameset_id, from_gameday_id, to_gameset_id, to_gameday_id,
                    team_valuation, remaining_budget, inplay_entities, reserved_entities,
                    created_date, updated_date
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,

            getUserTeams: `
                SELECT user_id, team_no, team_name, profanity_status, current_gameset_id,
                       team_valuation, remaining_budget, captain_player_id, vice_captain_player_id,
                       inplay_entities, reserved_entities, booster_id, booster_player_id,
                       transfers_allowed, transfers_made, transfers_left,
                       total_points, current_rank
                FROM user_teams_latest
                WHERE partition_id = ? AND user_bucket = ? AND user_id = ?`,

            updateTeamLatest: `
                UPDATE user_teams_latest
                SET current_gameset_id = ?, current_gameday_id = ?, team_valuation = ?,
                    remaining_budget = ?, captain_player_id = ?, vice_captain_player_id = ?,
                    inplay_entities = ?, reserved_entities = ?, booster_id = ?, booster_player_id = ?,
                    transfers_made = ?, transfers_left = ?, updated_date = ?
                WHERE partition_id = ? AND user_bucket = ? AND user_id = ? AND team_no = ?`,

            updateTeamDetailsStatus: `
                UPDATE user_team_details
                SET to_gameset_id = ?, to_gameday_id = ?, updated_date = ?
                WHERE partition_id = ? AND user_bucket = ? AND gameset_id = ?
                  AND user_id = ? AND team_no = ? AND gameday_id = ? IF EXISTS`,

            // Transfer operations
            insertTransfer: `
                INSERT INTO user_team_transfers (
                    partition_id, user_bucket, user_id, season_id, team_no, transfer_id,
                    gameset_id, gameday_id, action_type, booster_id, booster_player_id,
                    entities_in, entities_out, original_team_players, new_team_players,
                    transfers_made, transfer_cost, transfer_metadata, device_id, created_date, updated_date
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        };

        for (const [name, query] of Object.entries(statements)) {
            this.preparedStatements.set(name, await this.client.prepare(query));
        }

        console.log('✅ Prepared statements created successfully'.green);
    }

    async shutdown() {
        if (this.client) {
            await this.client.shutdown();
            console.log('🔌 Disconnected from Cassandra'.yellow);
        }
    }
}

// ====================================================================
// UTILITY FUNCTIONS
// ====================================================================

function calculatePartitionId(sourceId) {
    let hash = 0;
    for (let i = 0; i < sourceId.length; i++) {
        hash = ((hash << 5) - hash) + sourceId.charCodeAt(i);
        hash = hash & hash;
    }
    return Math.abs(hash) % 10;
}

function calculateUserBucket(userId) {
    return userId % 100;
}

function generateUserData(userId) {
    const platform = SOURCE_PLATFORMS[Math.floor(Math.random() * SOURCE_PLATFORMS.length)];
    const sourceId = `${platform.prefix}${Math.floor(Math.random() * 900000000) + 100000000}`;
    
    return {
        userId,
        sourceId,
        userGuid: uuidv4(),
        firstName: FIRST_NAMES[Math.floor(Math.random() * FIRST_NAMES.length)],
        lastName: LAST_NAMES[Math.floor(Math.random() * LAST_NAMES.length)],
        userName: `player_${userId}`,
        deviceId: Math.floor(Math.random() * 4) + 1,
        deviceVersion: ['1.0', '1.1', '1.2', '2.0'][Math.floor(Math.random() * 4)],
        loginPlatformSource: platform.id,
        partitionId: calculatePartitionId(sourceId),
        userBucket: calculateUserBucket(userId)
    };
}

function generateTeamData(userData, teamNo) {
    // Select players ensuring proper formation
    const shuffledPlayers = [...FOOTBALL_PLAYERS].sort(() => 0.5 - Math.random());
    
    // Ensure we have at least 1 goalkeeper
    const goalkeepers = shuffledPlayers.filter(p => p.skillId === 5).slice(0, 1);
    const outfieldPlayers = shuffledPlayers.filter(p => p.skillId !== 5).slice(0, 10);
    
    const mainPlayers = [...goalkeepers, ...outfieldPlayers];
    const reservePlayers = shuffledPlayers.filter(p => !mainPlayers.includes(p)).slice(0, 4);

    const inplayEntities = mainPlayers.map((player, idx) => ({
        entityId: player.id,
        skillId: player.skillId,
        order: idx + 1
    }));

    const reservedEntities = reservePlayers.map((player, idx) => ({
        entityId: player.id,
        skillId: player.skillId,
        order: idx + 1
    }));

    const totalValuation = [...mainPlayers, ...reservePlayers]
        .reduce((sum, player) => sum + player.price, 0);

    return {
        teamNo,
        teamName: TEAM_NAMES[Math.floor(Math.random() * TEAM_NAMES.length)],
        teamValuation: totalValuation,
        remainingBudget: 100.0 - totalValuation,
        captainPlayerId: mainPlayers[0].id,
        viceCaptainPlayerId: mainPlayers[1].id,
        inplayEntities: JSON.stringify(inplayEntities),
        reservedEntities: JSON.stringify(reservedEntities),
        boosterId: Math.floor(Math.random() * 3) + 1,
        boosterPlayerId: mainPlayers[Math.floor(Math.random() * mainPlayers.length)].id,
        transfersAllowed: 5,
        transfersMade: Math.floor(Math.random() * 4),
        transfersLeft: function () { return this.transfersAllowed - this.transfersMade; }
    };
}

function logPerformance(operation, duration, success = true) {
    if (success) {
        performanceStats[operation].push(duration);
    } else {
        performanceStats.errors.push({
            operation,
            duration,
            timestamp: new Date().toISOString()
        });
    }
}

// ====================================================================
// VALIDATION FUNCTIONS
// ====================================================================

function validateFormation(inplayEntities) {
    const skillCounts = {};
    const issues = [];
    
    // Count players by skill/position
    inplayEntities.forEach(entity => {
        skillCounts[entity.skillId] = (skillCounts[entity.skillId] || 0) + 1;
    });

    // Check total team size
    const totalPlayers = inplayEntities.length;
    if (totalPlayers !== 11) {
        issues.push(`Team must have exactly 11 players, found ${totalPlayers}`);
    }

    // Validate each position against formation rules
    let formationValid = true;
    Object.entries(FORMATION_RULES).forEach(([skillId, rules]) => {
        const count = skillCounts[skillId] || 0;
        const skillName = SKILL_POSITIONS[skillId];
        
        if (count < rules.min) {
            issues.push(`Not enough ${skillName}s: minimum ${rules.min}, found ${count}`);
            formationValid = false;
        }
        if (count > rules.max) {
            issues.push(`Too many ${skillName}s: maximum ${rules.max}, found ${count}`);
            formationValid = false;
        }
    });

    return {
        valid: formationValid && totalPlayers === 11,
        error: issues.length > 0 ? `Formation invalid: ${issues.join('; ')}` : null,
        issues: issues,
        currentFormation: skillCounts
    };
}

function validateBudget(inplayEntities, currentRemainingBudget) {
    let totalCost = 0;
    const playerCosts = [];

    inplayEntities.forEach(entity => {
        const player = FOOTBALL_PLAYERS.find(p => p.id === entity.entityId);
        if (player) {
            totalCost += player.price;
            playerCosts.push({ playerId: entity.entityId, cost: player.price });
        } else {
            // If player not found, assume a default cost for POC
            totalCost += 5.0;
            playerCosts.push({ playerId: entity.entityId, cost: 5.0 });
        }
    });

    const budgetLimit = 100.0;
    const newRemainingBudget = budgetLimit - totalCost;
    const budgetValid = totalCost <= budgetLimit;

    return {
        valid: budgetValid,
        error: budgetValid ? null : `Team cost ${totalCost.toFixed(1)} exceeds budget limit ${budgetLimit.toFixed(1)}`,
        newValuation: totalCost,
        newRemainingBudget: Math.max(0, newRemainingBudget),
        requiredBudget: totalCost,
        availableBudget: budgetLimit,
        playerCosts: playerCosts
    };
}

// ====================================================================
// API IMPLEMENTATION FUNCTIONS
// ====================================================================

class FantasyGameAPI {
    constructor(cassandraConn) {
        this.db = cassandraConn;
    }

    async userLogin(sourceId, deviceId, loginPlatformSource, userData = null) {
        const startTime = Date.now();
        const partitionId = calculatePartitionId(sourceId);
        
        try {
            // First, try to find existing user
            const getUserStmt = this.db.preparedStatements.get('getUserBySource');
            const result = await this.db.client.execute(getUserStmt, [
                partitionId, sourceId
            ]);

            if (result.rows.length > 0) {
                // User exists, get full profile
                const userRow = result.rows[0];
                const profile = await this.getUserProfile(userRow.user_id, partitionId);
                
                const duration = Date.now() - startTime;
                logPerformance('userLogin', duration);
                
                return {
                    success: true,
                    user_id: userRow.user_id,
                    user_guid: userRow.user_guid.toString(),
                    profile: profile
                };
            } else {
                // User doesn't exist, create new user
                if (!userData) {
                    const maxUserId = Math.floor(Math.random() * 1000000) + 100000;
                    userData = generateUserData(maxUserId);
                    userData.sourceId = sourceId;
                    userData.deviceId = deviceId;
                    userData.loginPlatformSource = loginPlatformSource;
                    userData.partitionId = partitionId;
                }

                const now = new Date();
                const userProperties = JSON.stringify([
                    { key: 'residence_country', value: 'US' },
                    { key: 'subscription_active', value: '1' },
                    { key: 'profile_pic_url', value: `https://example.com/pic_${userData.userId}.jpg` }
                ]);

                const userPreferences = JSON.stringify([
                    { preference: 'country', value: 1 },
                    { preference: 'team_1', value: 1 },
                    { preference: 'team_2', value: 2 },
                    { preference: 'tnc', value: 1 }
                ]);

                // Insert into main users table
                const userStmt = this.db.preparedStatements.get('insertUser');
                await this.db.client.execute(userStmt, [
                    userData.partitionId, userData.userId, userData.sourceId,
                    cassandra.types.Uuid.fromString(userData.userGuid), 
                    userData.firstName, userData.lastName, userData.userName,
                    userData.deviceId, userData.deviceVersion, userData.loginPlatformSource,
                    1, true, userProperties, userPreferences, 
                    '{"email": true, "sms": false}', now, now, now
                ]);

                // Insert into lookup table
                const lookupStmt = this.db.preparedStatements.get('insertUserBySource');
                await this.db.client.execute(lookupStmt, [
                    userData.partitionId, userData.sourceId, userData.userId,
                    cassandra.types.Uuid.fromString(userData.userGuid), 
                    userData.loginPlatformSource, now
                ]);

                const duration = Date.now() - startTime;
                logPerformance('userLogin', duration);

                return {
                    success: true,
                    user_id: userData.userId,
                    user_guid: userData.userGuid,
                    profile: {
                        user_id: userData.userId,
                        source_id: userData.sourceId,
                        user_guid: userData.userGuid,
                        first_name: userData.firstName,
                        last_name: userData.lastName,
                        user_name: userData.userName,
                        device_id: userData.deviceId,
                        login_platform_source: userData.loginPlatformSource,
                        profanity_status: 1,
                        preferences_saved: true,
                        user_properties: userProperties,
                        user_preferences: userPreferences
                    }
                };
            }
        } catch (error) {
            logPerformance('userLogin', Date.now() - startTime, false);
            console.error('User login failed:', error);
            return { success: false, error: error.message };
        }
    }

    async getUserProfile(userId, partitionId) {
        const startTime = Date.now();
        
        try {
            const stmt = this.db.preparedStatements.get('getUserProfile');
            const result = await this.db.client.execute(stmt, [partitionId, userId]);
            
            if (result.rows.length === 0) {
                logPerformance('getUserProfile', Date.now() - startTime, false);
                return null;
            }

            const row = result.rows[0];
            const duration = Date.now() - startTime;
            logPerformance('getUserProfile', duration);

            return {
                user_id: row.user_id,
                source_id: row.source_id,
                user_guid: row.user_guid.toString(),
                first_name: row.first_name,
                last_name: row.last_name,
                user_name: row.user_name,
                device_id: row.device_id,
                login_platform_source: row.login_platform_source,
                profanity_status: row.profanity_status,
                preferences_saved: row.preferences_saved,
                user_properties: row.user_properties,
                user_preferences: row.user_preferences,
                created_date: row.created_date
            };
        } catch (error) {
            logPerformance('getUserProfile', Date.now() - startTime, false);
            console.error(`Get user profile failed for user ${userId}:`, error.message);
            return null;
        }
    }

    async saveTeam(userData, teamData, gamesetId, gamedayId, fantasyType = 1) {
        const startTime = Date.now();
        const now = new Date();
        const transferId = uuidv4();

        // Resolve prepared statements
        const insertTeamLatestStmt = this.db.preparedStatements.get('insertTeamLatest');
        const insertTeamDetailsStmt = this.db.preparedStatements.get('insertTeamDetails');
        const insertTransferStmt = this.db.preparedStatements.get('insertTransfer');

        try {
            // Step 1: Insert/Update current team state
            await this.db.client.execute(insertTeamLatestStmt, [
                userData.partitionId, userData.userBucket, userData.userId,
                teamData.teamNo, gamesetId, gamedayId,
                teamData.teamName, teamData.teamName.toUpperCase(),
                1, // profanity_status
                teamData.teamValuation, teamData.remainingBudget,
                teamData.captainPlayerId, teamData.viceCaptainPlayerId,
                teamData.inplayEntities, teamData.reservedEntities,
                teamData.boosterId, teamData.boosterPlayerId,
                teamData.transfersAllowed, teamData.transfersMade, teamData.transfersLeft(),
                0, 0, // total_points, current_rank
                userData.deviceId, now, now
            ]);

            // Step 2: Insert gameset-specific historical record
            const toGamesetId = -1;
            await this.db.client.execute(insertTeamDetailsStmt, [
                userData.partitionId, userData.userBucket, gamesetId,
                userData.userId, teamData.teamNo, gamedayId,
                gamesetId, gamedayId, // from_gameset_id, from_gameday_id
                toGamesetId, null, // to_gameset_id, to_gameday_id
                teamData.teamValuation, teamData.remainingBudget,
                teamData.inplayEntities, teamData.reservedEntities,
                now, now
            ]);

            // Step 3: Log the team creation
            await this.db.client.execute(insertTransferStmt, [
                userData.partitionId, userData.userBucket, userData.userId, CURRENT_SEASON,
                teamData.teamNo, transferId,
                gamesetId, gamedayId, 'CREATE',
                teamData.boosterId, teamData.boosterPlayerId,
                '[]', '[]', // entities_in, entities_out (empty for creation)
                '[]', teamData.inplayEntities, // original_team_players, new_team_players
                0, 0.0, // transfers_made, transfer_cost
                JSON.stringify({ action: 'team_created', fantasy_type: fantasyType }),
                userData.deviceId, now, now
            ]);

            const duration = Date.now() - startTime;
            logPerformance('saveTeam', duration);
            return { success: true, transferId };
        } catch (error) {
            logPerformance('saveTeam', Date.now() - startTime, false);
            console.error('Save team failed:', error);
            return { success: false, error: error.message };
        }
    }

    async transferTeam(userData, teamNo, entitiesIn, entitiesOut, 
                       currentGamesetId, currentGamedayId, captainId, viceCaptainId, 
                       boosterId = null, boosterPlayerId = null, fantasyType = 1) {
        const startTime = Date.now();
        const now = new Date();
        const transferId = uuidv4();

        try {
            // Step 1: Get current team state
            const currentTeam = await this.getCurrentTeamState(userData, teamNo);
            if (!currentTeam) {
                return { 
                    success: false, 
                    error: `Team ${teamNo} not found for user ${userData.userId}`,
                    errorCode: 'TEAM_NOT_FOUND'
                };
            }

            // Step 2: Validate transfer limits
            const currentTransfersMade = currentTeam.transfers_made || 0;
            const transfersAllowed = currentTeam.transfers_allowed || 5;
            const freeTransfersLeft = Math.max(0, transfersAllowed - currentTransfersMade);
            
            if (entitiesOut.length > freeTransfersLeft && entitiesOut.length > 0) {
                return {
                    success: false,
                    error: `Transfer limit exceeded. You have ${freeTransfersLeft} free transfers left but trying to make ${entitiesOut.length} transfers.`,
                    errorCode: 'TRANSFER_LIMIT_EXCEEDED',
                    transfersLeft: freeTransfersLeft,
                    transfersRequested: entitiesOut.length
                };
            }

            // Step 3: Validate player ownership
            const currentInplay = JSON.parse(currentTeam.inplay_entities || '[]');
            const currentReserved = JSON.parse(currentTeam.reserved_entities || '[]');
            const ownedPlayerIds = [...currentInplay, ...currentReserved].map(p => p.entityId);

            const invalidTransferOut = entitiesOut.filter(entity => 
                !ownedPlayerIds.includes(entity.entity_id)
            );

            if (invalidTransferOut.length > 0) {
                return {
                    success: false,
                    error: `Cannot transfer players you don't own: ${invalidTransferOut.map(e => e.entity_id).join(', ')}`,
                    errorCode: 'INVALID_PLAYER_OWNERSHIP',
                    invalidPlayers: invalidTransferOut.map(e => e.entity_id)
                };
            }

            // Step 4: Calculate new team composition
            let newInplay = currentInplay.filter(entity => 
                !entitiesOut.some(outEntity => outEntity.entity_id === entity.entityId)
            );
            
            // Add new entities from entities_in
            entitiesIn.forEach(inEntity => {
                newInplay.push({
                    entityId: inEntity.entity_id,
                    skillId: inEntity.skill_id,
                    order: inEntity.order
                });
            });

            // Step 5: Validate formation
            const formationValidation = validateFormation(newInplay);
            if (!formationValidation.valid) {
                return {
                    success: false,
                    error: formationValidation.error,
                    errorCode: 'INVALID_FORMATION',
                    formationIssues: formationValidation.issues
                };
            }

            // Step 6: Validate budget constraints
            const budgetValidation = validateBudget(newInplay, currentTeam.remaining_budget || 15.0);
            if (!budgetValidation.valid) {
                return {
                    success: false,
                    error: budgetValidation.error,
                    errorCode: 'BUDGET_EXCEEDED',
                    requiredBudget: budgetValidation.requiredBudget,
                    availableBudget: budgetValidation.availableBudget
                };
            }

            const fromGamesetId = currentTeam.current_gameset_id;
            const sameGameset = fromGamesetId === currentGamesetId;

            // Step 7: Execute transfer logic
            const newInplayEntities = JSON.stringify(newInplay);
            const newReservedEntities = currentTeam.reserved_entities;
            const newTeamValuation = budgetValidation.newValuation;
            const newRemainingBudget = budgetValidation.newRemainingBudget;
            const newTransfersMade = currentTransfersMade + entitiesOut.length;
            const newTransfersLeft = Math.max(0, transfersAllowed - newTransfersMade);

            // Get prepared statements
            const updateTeamLatestStmt = this.db.preparedStatements.get('updateTeamLatest');
            const insertTeamDetailsStmt = this.db.preparedStatements.get('insertTeamDetails');
            const updateTeamDetailsStmt = this.db.preparedStatements.get('updateTeamDetailsStatus');
            const insertTransferStmt = this.db.preparedStatements.get('insertTransfer');

            if (sameGameset) {
                // SCENARIO A: Same Gameset - Update existing records
                console.log(`🔄 Transfer within same gameset ${currentGamesetId}`.cyan);
                
                await this.db.client.execute(updateTeamLatestStmt, [
                    currentGamesetId, currentGamedayId,
                    newTeamValuation, newRemainingBudget,
                    captainId || currentTeam.captain_player_id,
                    viceCaptainId || currentTeam.vice_captain_player_id,
                    newInplayEntities, newReservedEntities,
                    boosterId || currentTeam.booster_id || 1,
                    boosterPlayerId || currentTeam.booster_player_id || currentInplay[0]?.entityId,
                    newTransfersMade, newTransfersLeft, now,
                    userData.partitionId, userData.userBucket, userData.userId, teamNo
                ]);

            } else {
                // SCENARIO B: Different Gameset - Close previous, create new
                console.log(`🔄 Transfer to different gameset: ${fromGamesetId} → ${currentGamesetId}`.cyan);
                
                // Close previous gameset record
                if (updateTeamDetailsStmt) {
                    await this.db.client.execute(updateTeamDetailsStmt, [
                        currentGamesetId - 1, currentGamedayId - 1, now,
                        userData.partitionId, userData.userBucket, fromGamesetId,
                        userData.userId, teamNo, currentTeam.current_gameday_id
                    ]);
                }

                // Create new gameset record
                await this.db.client.execute(insertTeamDetailsStmt, [
                    userData.partitionId, userData.userBucket, currentGamesetId,
                    userData.userId, teamNo, currentGamedayId,
                    currentGamesetId, currentGamedayId,
                    -1, null, // to_gameset_id, to_gameday_id
                    newTeamValuation, newRemainingBudget,
                    newInplayEntities, newReservedEntities,
                    now, now
                ]);

                // Update user_teams_latest
                await this.db.client.execute(updateTeamLatestStmt, [
                    currentGamesetId, currentGamedayId,
                    newTeamValuation, newRemainingBudget,
                    captainId || currentTeam.captain_player_id,
                    viceCaptainId || currentTeam.vice_captain_player_id,
                    newInplayEntities, newReservedEntities,
                    boosterId || currentTeam.booster_id || 1,
                    boosterPlayerId || currentTeam.booster_player_id || newInplay[0]?.entityId,
                    newTransfersMade, newTransfersLeft, now,
                    userData.partitionId, userData.userBucket, userData.userId, teamNo
                ]);
            }

            // Step 8: Log the transfer
            await this.db.client.execute(insertTransferStmt, [
                userData.partitionId, userData.userBucket, userData.userId, CURRENT_SEASON,
                teamNo, transferId,
                currentGamesetId, currentGamedayId, 'TRANSFER',
                boosterId || currentTeam.booster_id || 1,
                boosterPlayerId || currentTeam.booster_player_id || newInplay[0]?.entityId,
                JSON.stringify(entitiesIn), JSON.stringify(entitiesOut),
                currentTeam.inplay_entities, newInplayEntities,
                newTransfersMade, 0.0, // transfer_cost
                JSON.stringify({
                    gameset_changed: !sameGameset,
                    same_gameset: sameGameset,
                    from_gameset_id: fromGamesetId,
                    to_gameset_id: currentGamesetId,
                    fantasy_type: fantasyType,
                    formation_valid: true,
                    budget_valid: true
                }),
                userData.deviceId, now, now
            ]);

            const duration = Date.now() - startTime;
            logPerformance('transferTeam', duration);

            return { 
                success: true, 
                transferId, 
                gamesetChanged: !sameGameset,
                sameGameset: sameGameset,
                newTransfersMade,
                newTransfersLeft,
                newTeamValuation,
                newRemainingBudget,
                formationValid: true,
                budgetValid: true
            };

        } catch (error) {
            logPerformance('transferTeam', Date.now() - startTime, false);
            console.error('Transfer team failed:', error);
            return { success: false, error: error.message, errorCode: 'SYSTEM_ERROR' };
        }
    }

    async getCurrentTeamState(userData, teamNo) {
        const stmt = this.db.preparedStatements.get('getUserTeams');
        const result = await this.db.client.execute(stmt, [
            userData.partitionId, userData.userBucket, userData.userId
        ]);
        return result.rows.find(row => row.team_no === teamNo);
    }

    async getUserTeams(userData, gamesetId) {
        const startTime = Date.now();
        try {
            const stmt = this.db.preparedStatements.get('getUserTeams');
            const result = await this.db.client.execute(stmt, [
                userData.partitionId, userData.userBucket, userData.userId
            ]);

            const teams = result.rows.map(row => {
                const inplayEntities = JSON.parse(row.inplay_entities || '[]');
                const reservedEntities = JSON.parse(row.reserved_entities || '[]');
                
                const formation = [
                    { skillId: 1, playerCount: 4 }, // Defenders
                    { skillId: 2, playerCount: 4 }, // Midfielders
                    { skillId: 3, playerCount: 2 }, // Forwards
                    { skillId: 4, playerCount: 1 } // Striker
                ];

                return {
                    teamNo: row.team_no,
                    teamName: row.team_name,
                    profanityStatus: row.profanity_status,
                    transfers: {
                        freeLimit: row.transfers_allowed,
                        freeMade: Math.min(row.transfers_made, row.transfers_allowed),
                        extraMade: Math.max(0, row.transfers_made - row.transfers_allowed),
                        totalMade: row.transfers_made
                    },
                    boosters: row.booster_id ? [{ boosterId: row.booster_id, playerId: row.booster_player_id }] : [],
                    formation,
                    budget: {
                        limit: 100,
                        utilized: row.team_valuation,
                        left: row.remaining_budget
                    },
                    inplayEntities,
                    reservedEntities,
                    points: row.total_points ? String(Math.floor(row.total_points)) : null,
                    rank: row.current_rank || 0
                };
            });

            const duration = Date.now() - startTime;
            logPerformance('getUserTeams', duration);

            return {
                teamCreatedCount: teams.length,
                maxTeamAllowed: 5,
                rank: teams.length > 0 ? teams[0].rank : 0,
                totalPoints: String(teams.reduce((sum, team) => sum + parseFloat(team.points || 0), 0)),
                teams
            };
        } catch (error) {
            logPerformance('getUserTeams', Date.now() - startTime, false);
            console.error(`Get teams failed for user ${userData.userId}:`, error.message);
            return null;
        }
    }
}

// ====================================================================
// TEST DATA GENERATION & POPULATION
// ====================================================================

async function populateTestData(api, numUsers) {
    console.log(`🔄 Generating test data for ${numUsers} users...`.cyan);
    const usersData = [];
    const batchSize = Math.min(100, Math.max(10, Math.floor(numUsers / 100)));

    for (let i = 0; i < numUsers; i += batchSize) {
        const batch = [];
        const endIndex = Math.min(i + batchSize, numUsers);

        for (let userId = i + 1; userId <= endIndex; userId++) {
            const userData = generateUserData(userId);
            usersData.push(userData);

            const now = new Date();
            const userProperties = JSON.stringify([
                { key: 'residence_country', value: ['US', 'UK', 'IN', 'CA'][Math.floor(Math.random() * 4)] },
                { key: 'subscription_active', value: '1' },
                { key: 'profile_pic_url', value: `https://example.com/pic_${userId}.jpg` }
            ]);

            const userPreferences = JSON.stringify([
                { preference: 'country', value: Math.floor(Math.random() * 5) + 1 },
                { preference: 'team_1', value: Math.floor(Math.random() * 20) + 1 },
                { preference: 'team_2', value: Math.floor(Math.random() * 20) + 1 },
                { preference: 'tnc', value: 1 }
            ]);

            const userPromise = async () => {
                try {
                    // Insert into main users table
                    const userStmt = api.db.preparedStatements.get('insertUser');
                    await api.db.client.execute(userStmt, [
                        userData.partitionId, userData.userId, userData.sourceId,
                        cassandra.types.Uuid.fromString(userData.userGuid), 
                        userData.firstName, userData.lastName, userData.userName, 
                        userData.deviceId, userData.deviceVersion, userData.loginPlatformSource,
                        1, true, userProperties, userPreferences, 
                        '{"email": true, "sms": false}', now, now, now
                    ]);

                    // Insert into lookup table
                    const lookupStmt = api.db.preparedStatements.get('insertUserBySource');
                    await api.db.client.execute(lookupStmt, [
                        userData.partitionId, userData.sourceId, userData.userId,
                        cassandra.types.Uuid.fromString(userData.userGuid), 
                        userData.loginPlatformSource, now
                    ]);
                } catch (error) {
                    console.error(`Failed to create user ${userId}:`, error.message);
                }
            };

            batch.push(userPromise());
        }

        // Execute batch sequentially
        for (const userPromise of batch) {
            await userPromise;
        }

        // Progress indicator
        const progressInterval = Math.max(200, Math.floor(numUsers / 50));
        if (i % progressInterval === 0 || endIndex === numUsers) {
            console.log(`📊 Created ${endIndex}/${numUsers} users (${Math.round(endIndex / numUsers * 100)}%)`.green);
        }
    }

    console.log(`✅ Successfully created ${usersData.length} users`.green);
    return usersData;
}

// ====================================================================
// PERFORMANCE TESTING & REPORTING
// ====================================================================

async function runPerformanceTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} performance tests...`.cyan);
    const concurrencyLevel = Math.min(20, Math.max(3, Math.floor(numTests / 1000)));
    const testPromises = [];

    for (let i = 0; i < numTests; i++) {
        const testPromise = async () => {
            const userData = usersData[Math.floor(Math.random() * usersData.length)];

            try {
                // Test 1: User Login
                const loginResult = await api.userLogin(userData.sourceId, userData.deviceId, userData.loginPlatformSource);
                
                if (loginResult.success) {
                    // Test 2: Get User Profile
                    await api.getUserProfile(userData.userId, userData.partitionId);

                    // Test 3: Save Team (create new team)
                    const teamData = generateTeamData(userData, Math.floor(Math.random() * 3) + 1);
                    const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);

                    // Test 4: Get User Teams
                    await api.getUserTeams(userData, CURRENT_GAMESET);

                    // Test 5: Transfer Team (30% chance) with validation
                    if (saveResult.success && Math.random() < 0.3) {
                        // Create realistic transfer scenario
                        const validEntitiesIn = [{ 
                            entity_id: FOOTBALL_PLAYERS[Math.floor(Math.random() * 15)].id,
                            skill_id: Math.floor(Math.random() * 4) + 1, 
                            order: 1 
                        }];
                        const validEntitiesOut = [{ 
                            entity_id: JSON.parse(teamData.inplayEntities)[0].entityId,
                            skill_id: Math.floor(Math.random() * 4) + 1, 
                            order: 1 
                        }];
                        
                        const transferResult = await api.transferTeam(
                            userData, teamData.teamNo, validEntitiesIn, validEntitiesOut, 
                            CURRENT_GAMESET, CURRENT_GAMEDAY,
                            teamData.captainPlayerId, teamData.viceCaptainPlayerId
                        );

                        // Log transfer validation results for analysis
                        if (!transferResult.success) {
                            console.log(`⚠️ Transfer validation failed: ${transferResult.errorCode}`.yellow);
                            performanceStats.transferValidationErrors.push({
                                errorCode: transferResult.errorCode,
                                error: transferResult.error
                            });
                        }
                    }
                }
            } catch (error) {
                console.error('Test execution error:', error.message);
            }
        };

        testPromises.push(testPromise());

        if (testPromises.length >= concurrencyLevel) {
            await Promise.all(testPromises);
            testPromises.length = 0;

            if (numTests > 10000 && (i + 1) % Math.floor(numTests / 20) === 0) {
                console.log(`⏱️ Progress: ${i + 1}/${numTests} tests (${Math.round((i + 1) / numTests * 100)}%)`.cyan);
            }
        }
    }

    if (testPromises.length > 0) {
        await Promise.all(testPromises);
    }

    console.log('✅ Performance tests completed'.green);
}

function generatePerformanceReport() {
    const report = {
        timestamp: new Date().toISOString(),
        summary: {},
        detailedStats: {}
    };

    Object.entries(performanceStats).forEach(([operation, times]) => {
        if (operation === 'errors' || operation === 'transferValidationErrors' || times.length === 0) return;

        times.sort((a, b) => a - b);
        const avg = times.reduce((sum, time) => sum + time, 0) / times.length;
        const median = times[Math.floor(times.length / 2)];
        const min = times[0];
        const max = times[times.length - 1];
        const p95 = times[Math.floor(times.length * 0.95)] || 'N/A';
        const p99 = times[Math.floor(times.length * 0.99)] || 'N/A';

        const stats = {
            operation,
            totalCalls: times.length,
            avgTimeMs: Math.round(avg * 100) / 100,
            medianTimeMs: Math.round(median * 100) / 100,
            minTimeMs: Math.round(min * 100) / 100,
            maxTimeMs: Math.round(max * 100) / 100,
            p95TimeMs: p95 !== 'N/A' ? Math.round(p95 * 100) / 100 : 'N/A',
            p99TimeMs: p99 !== 'N/A' ? Math.round(p99 * 100) / 100 : 'N/A'
        };

        report.detailedStats[operation] = stats;
        report.summary[operation] = `${stats.avgTimeMs}ms avg, ${stats.totalCalls} calls`;
    });

    // Error summary
    const totalOperations = Object.values(performanceStats)
        .filter(times => Array.isArray(times) && times.length > 0)
        .reduce((sum, times) => sum + times.length, 0);

    report.errors = {
        totalErrors: performanceStats.errors.length,
        transferValidationErrors: performanceStats.transferValidationErrors.length,
        errorRate: totalOperations > 0
            ? `${((performanceStats.errors.length / totalOperations) * 100).toFixed(2)}%`
            : '0%'
    };

    return report;
}

function printPerformanceReport(report) {
    console.log('\n' + '='.repeat(80).yellow);
    console.log('FANTASY GAME CASSANDRA POC - PERFORMANCE REPORT'.bold.yellow);
    console.log('='.repeat(80).yellow);
    console.log(`Generated: ${report.timestamp}`.cyan);
    console.log(`Total Errors: ${report.errors.totalErrors} (${report.errors.errorRate})`.red);
    console.log(`Transfer Validation Errors: ${report.errors.transferValidationErrors}`.yellow);
    console.log();

    console.log('OPERATION PERFORMANCE SUMMARY:'.bold.green);
    console.log('-'.repeat(50).green);
    Object.entries(report.summary).forEach(([operation, summary]) => {
        console.log(`${operation.toUpperCase().padEnd(20)} | ${summary}`.white);
    });

    console.log('\nDETAILED STATISTICS:'.bold.blue);
    console.log('-'.repeat(80).blue);
    console.log('Operation        Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)'.bold);
    console.log('-'.repeat(80).blue);

    Object.values(report.detailedStats).forEach(stats => {
        console.log(
            `${stats.operation.padEnd(15)} ` +
            `${String(stats.totalCalls).padEnd(8)} ` +
            `${String(stats.avgTimeMs).padEnd(8)} ` +
            `${String(stats.medianTimeMs).padEnd(8)} ` +
            `${String(stats.minTimeMs).padEnd(8)} ` +
            `${String(stats.maxTimeMs).padEnd(8)} ` +
            `${String(stats.p95TimeMs).padEnd(8)} ` +
            `${String(stats.p99TimeMs).padEnd(8)}`
        );
    });

    console.log('\n' + '='.repeat(80).yellow);
}

// ====================================================================
// MAIN EXECUTION
// ====================================================================

async function main() {
    program
        .option('--users <number>', 'Number of users to create', DEFAULT_USERS)
        .option('--tests <number>', 'Number of performance tests to run', DEFAULT_TESTS)
        .option('--skip-data', 'Skip test data generation')
        .option('--report-file <file>', 'Save performance report to file')
        .parse(process.argv);

    const options = program.opts();
    const numUsers = parseInt(options.users);
    const numTests = parseInt(options.tests);

    console.log('🎮 Starting Fantasy Game Cassandra POC (Node.js)'.bold.cyan);
    console.log(`📊 Configuration: ${numUsers} users, ${numTests} tests`.gray);

    // Connect to Cassandra
    const cassandraConn = new CassandraConnection();
    if (!(await cassandraConn.connect())) {
        console.error('❌ Failed to connect to Cassandra. Exiting.'.red);
        process.exit(1);
    }

    try {
        const api = new FantasyGameAPI(cassandraConn);

        // Generate test data
        let usersData;
        if (!options.skipData) {
            if (numUsers > 10000) {
                console.log(`⚠️ WARNING: Creating ${numUsers} users will take significant time. Consider using --skip-data for large tests.`.yellow);
            }
            usersData = await populateTestData(api, numUsers);
        } else {
            console.log(`📊 Generating user data structures for ${numUsers} users (no database inserts)...`.cyan);
            usersData = Array.from({ length: numUsers }, (_, i) => generateUserData(i + 1));
            console.log(`✅ Generated ${usersData.length} user data structures`.green);
        }

        // Run performance tests
        console.log('⏱️ Starting performance tests...'.cyan);
        const startTime = Date.now();
        await runPerformanceTests(api, usersData, numTests);
        const totalTestTime = Date.now() - startTime;

        // Generate and display report
        const report = generatePerformanceReport();
        report.testDurationSeconds = Math.round(totalTestTime / 1000 * 100) / 100;
        report.throughputOpsPerSecond = Math.round((numTests / (totalTestTime / 1000)) * 100) / 100;

        printPerformanceReport(report);

        // Save report if requested
        if (options.reportFile) {
            await fs.writeFile(options.reportFile, JSON.stringify(report, null, 2));
            console.log(`💾 Performance report saved to ${options.reportFile}`.green);
        }

        console.log('🎉 POC testing completed successfully'.bold.green);
    } catch (error) {
        console.error('❌ POC testing failed:'.red, error.message);
        throw error;
    } finally {
        await cassandraConn.shutdown();
    }
}

// Handle graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...'.yellow);
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\n🛑 Received SIGTERM, shutting down gracefully...'.yellow);
    process.exit(0);
});

// Run the application
if (require.main === module) {
    main().catch(error => {
        console.error('💥 Fatal error:'.red, error);
        process.exit(1);
    });
}

module.exports = { main, FantasyGameAPI, CassandraConnection };
