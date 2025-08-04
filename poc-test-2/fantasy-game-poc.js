#!/usr/bin/env node

/**
 * Fantasy Game ScyllaDB POC Testing Script - Node.js Version
 * ==========================================================
 * 
 * This script tests core fantasy game APIs against ScyllaDB to evaluate
 * performance compared to Cassandra and PostgreSQL. It includes realistic 
 * football data and comprehensive performance metrics.
 * 
 * Usage:
 * node fantasy-game-scylladb-poc.js --users 1000 --tests 100
 */

const cassandra = require('cassandra-driver');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const path = require('path');
const { program } = require('commander');
const colors = require('colors');

// ====================================================================
// SCYLLADB CONFIGURATION & SETUP
// ====================================================================

const SCYLLADB_CONFIG = {
    contactPoints: ['127.0.0.1:9042', '127.0.0.1:9043', '127.0.0.1:9044'],
    localDataCenter: 'datacenter1',
    keyspace: 'fantasy_game',
    socketOptions: {
        readTimeout: 15000,  // Reduced for ScyllaDB's faster response
        connectTimeout: 8000  // Faster connection timeout
    },
    queryOptions: {
        consistency: cassandra.types.consistencies.localQuorum,
        retry: {
            times: 3,
            delay: 50  // Reduced retry delay for ScyllaDB
        },
        prepare: true,
        // ScyllaDB-specific optimizations
        autoPage: true,
        fetchSize: 5000
    },
    pooling: {
        // Optimized for ScyllaDB's shard-per-core architecture
        coreConnectionsPerHost: {
            [cassandra.types.distance.local]: 4,
            [cassandra.types.distance.remote]: 2
        },
        maxConnectionsPerHost: {
            [cassandra.types.distance.local]: 8,
            [cassandra.types.distance.remote]: 4
        }
    },
    // Enable ScyllaDB shard-aware port
    isShardAware: true
};

const DEFAULT_USERS = 1000;
const DEFAULT_TESTS = 100;
const CURRENT_SEASON = 2024;
const CURRENT_GAMESET = 15;
const CURRENT_GAMEDAY = 3;

// Enhanced performance tracking for ScyllaDB
const performanceStats = {
    saveTeam: [],
    getUserTeams: [],
    batchOperations: [],
    errors: [],
    scyllaMetrics: {
        shardAwareConnections: 0,
        cacheHits: 0,
        cacheMisses: 0
    }
};

// ====================================================================
// REALISTIC FANTASY FOOTBALL DATA (Same as original)
// ====================================================================

const FOOTBALL_PLAYERS = [
    { id: 1001, name: "Kevin De Bruyne", skillId: 2, price: 12.5, team: "Man City" },
    { id: 1002, name: "Mohamed Salah", skillId: 3, price: 13.0, team: "Liverpool" },
    { id: 1003, name: "Harry Kane", skillId: 4, price: 11.5, team: "Bayern Munich" },
    { id: 1004, name: "Virgil van Dijk", skillId: 1, price: 6.5, team: "Liverpool" },
    { id: 1005, name: "Sadio Mané", skillId: 3, price: 10.0, team: "Al Nassr" },
    { id: 1006, name: "N'Golo Kanté", skillId: 2, price: 5.5, team: "Al-Ittihad" },
    { id: 1007, name: "Sergio Ramos", skillId: 1, price: 5.0, team: "PSG" },
    { id: 1008, name: "Luka Modrić", skillId: 2, price: 8.5, team: "Real Madrid" },
    { id: 1009, name: "Robert Lewandowski", skillId: 4, price: 9.0, team: "Barcelona" },
    { id: 1010, name: "Kylian Mbappé", skillId: 3, price: 12.0, team: "PSG" },
    { id: 1011, name: "Alisson Becker", skillId: 5, price: 5.5, team: "Liverpool" },
    { id: 1012, name: "Mason Mount", skillId: 2, price: 6.5, team: "Man United" },
    { id: 1013, name: "Phil Foden", skillId: 3, price: 8.0, team: "Man City" },
    { id: 1014, name: "Bruno Fernandes", skillId: 2, price: 8.5, team: "Man United" },
    { id: 1015, name: "Erling Haaland", skillId: 4, price: 15.0, team: "Man City" },
    { id: 1016, name: "Thibaut Courtois", skillId: 5, price: 5.0, team: "Real Madrid" },
    { id: 1017, name: "Karim Benzema", skillId: 4, price: 10.0, team: "Al-Ittihad" },
    { id: 1018, name: "Pedri", skillId: 2, price: 6.0, team: "Barcelona" },
    { id: 1019, name: "Vinicius Jr.", skillId: 3, price: 9.5, team: "Real Madrid" },
    { id: 1020, name: "João Cancelo", skillId: 1, price: 7.0, team: "Man City" }
];

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
// SCYLLADB CONNECTION & UTILITIES
// ====================================================================

class ScyllaDBConnection {
    constructor() {
        this.client = null;
        this.preparedStatements = new Map();
        this.clusterMetadata = null;
    }

    async connect() {
        try {
            this.client = new cassandra.Client(SCYLLADB_CONFIG);
            await this.client.connect();

            // ScyllaDB-specific connection optimizations
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

            // Get ScyllaDB cluster information
            this.clusterMetadata = this.client.metadata;
            
            console.log('✅ Connected to ScyllaDB cluster'.green);
            console.log(`🎯 ScyllaDB Nodes: ${this.clusterMetadata.getAllHosts().length}`.cyan);
            
            // Check for shard-aware driver
            if (this.client.options.isShardAware) {
                console.log('⚡ Shard-aware driver enabled'.yellow);
                performanceStats.scyllaMetrics.shardAwareConnections++;
            }

            await this.prepareCQLStatements();
            return true;
        } catch (error) {
            console.error('❌ Failed to connect to ScyllaDB:'.red, error.message);
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

            // Team operations with ScyllaDB optimizations
            insertTeamLatest: `
                INSERT INTO user_teams_latest (
                    partition_id, user_bucket, user_id, team_no, current_gameset_id,
                    current_gameday_id, team_name, upper_team_name, profanity_status,
                    team_valuation, remaining_budget, captain_player_id, vice_captain_player_id,
                    inplay_entities, reserved_entities, booster_id, booster_player_id,
                    transfers_allowed, transfers_made, transfers_left,
                    total_points, current_rank, device_id, created_date, updated_date
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                USING TTL 31536000`,  // 1 year TTL for active data

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

        console.log('✅ ScyllaDB prepared statements created successfully'.green);
    }

    async shutdown() {
        if (this.client) {
            await this.client.shutdown();
            console.log('🔌 Disconnected from ScyllaDB'.yellow);
        }
    }

    // ScyllaDB-specific monitoring
    getClusterStats() {
        if (!this.clusterMetadata) return null;
        
        const hosts = this.clusterMetadata.getAllHosts();
        return {
            totalHosts: hosts.length,
            healthyHosts: hosts.filter(h => h.isUp()).length,
            datacenters: [...new Set(hosts.map(h => h.datacenter))],
            racks: [...new Set(hosts.map(h => h.rack))]
        };
    }
}

// ====================================================================
// UTILITY FUNCTIONS (Same as original with minor optimizations)
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
    const shuffledPlayers = [...FOOTBALL_PLAYERS].sort(() => 0.5 - Math.random());
    const mainPlayers = shuffledPlayers.slice(0, 11);
    const reservePlayers = shuffledPlayers.slice(11, 15);
    
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
// SCYLLADB API IMPLEMENTATION
// ====================================================================

class FantasyGameScyllaAPI {
    constructor(scyllaConn) {
        this.db = scyllaConn;
    }

    async saveTeam(userData, teamData, gamesetId, gamedayId, fantasyType = 1) {
        const startTime = Date.now();
        const now = new Date();
        const transferId = uuidv4();

        const insertTeamLatestStmt = this.db.preparedStatements.get('insertTeamLatest');
        const insertTeamDetailsStmt = this.db.preparedStatements.get('insertTeamDetails');
        const insertTransferStmt = this.db.preparedStatements.get('insertTransfer');

        try {
            // ScyllaDB batch optimization for better performance
            const batch = [
                {
                    query: insertTeamLatestStmt,
                    params: [
                        userData.partitionId, userData.userBucket, userData.userId,
                        teamData.teamNo, gamesetId, gamedayId,
                        teamData.teamName, teamData.teamName.toUpperCase(),
                        1, // profanity_status
                        teamData.teamValuation, teamData.remainingBudget,
                        teamData.captainPlayerId, teamData.viceCaptainPlayerId,
                        teamData.inplayEntities, teamData.reservedEntities,
                        teamData.boosterId, teamData.boosterPlayerId,
                        teamData.transfersAllowed, teamData.transfersMade, teamData.transfersLeft(),
                        0, 0, userData.deviceId, now, now
                    ]
                },
                {
                    query: insertTeamDetailsStmt,
                    params: [
                        userData.partitionId, userData.userBucket, gamesetId,
                        userData.userId, teamData.teamNo, gamedayId,
                        gamesetId, gamedayId, -1, null,
                        teamData.teamValuation, teamData.remainingBudget,
                        teamData.inplayEntities, teamData.reservedEntities,
                        now, now
                    ]
                },
                {
                    query: insertTransferStmt,
                    params: [
                        userData.partitionId, userData.userBucket, userData.userId, CURRENT_SEASON,
                        teamData.teamNo, transferId, gamesetId, gamedayId, 'CREATE',
                        teamData.boosterId, teamData.boosterPlayerId,
                        '[]', '[]', '[]', teamData.inplayEntities,
                        0, 0.0, JSON.stringify({ action: 'team_created', fantasy_type: fantasyType }),
                        userData.deviceId, now, now
                    ]
                }
            ];

            // Execute as batch for better ScyllaDB performance
            await this.db.client.batch(batch, { prepare: true });

            const duration = Date.now() - startTime;
            logPerformance('saveTeam', duration);
            return { success: true, transferId };
        } catch (error) {
            logPerformance('saveTeam', Date.now() - startTime, false);
            console.error('Save team failed:', error);
            return { success: false, error: error.message };
        }
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
                    { skillId: 4, playerCount: 1 }  // Striker
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
// ENHANCED PERFORMANCE TESTING FOR SCYLLADB
// ====================================================================

async function populateTestData(api, numUsers) {
    console.log(`🔄 Generating test data for ${numUsers} users in ScyllaDB...`.cyan);
    const usersData = [];
    const batchSize = Math.min(200, Math.max(20, Math.floor(numUsers / 50))); // Larger batches for ScyllaDB

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
                    // Use ScyllaDB batch for user creation
                    const userBatch = [
                        {
                            query: api.db.preparedStatements.get('insertUser'),
                            params: [
                                userData.partitionId, userData.userId, userData.sourceId,
                                cassandra.types.Uuid.fromString(userData.userGuid), 
                                userData.firstName, userData.lastName, userData.userName, 
                                userData.deviceId, userData.deviceVersion, userData.loginPlatformSource, 
                                1, true, userProperties, userPreferences, 
                                '{"email": true, "sms": false}', now, now, now
                            ]
                        },
                        {
                            query: api.db.preparedStatements.get('insertUserBySource'),
                            params: [
                                userData.partitionId, userData.sourceId, userData.userId,
                                cassandra.types.Uuid.fromString(userData.userGuid), 
                                userData.loginPlatformSource, now
                            ]
                        }
                    ];

                    await api.db.client.batch(userBatch, { prepare: true });
                } catch (error) {
                    console.error(`Failed to create user ${userId}:`, error.message);
                }
            };

            batch.push(userPromise());
        }

        // Execute batch with higher concurrency for ScyllaDB
        await Promise.all(batch);

        // Progress indicator
        const progressInterval = Math.max(100, Math.floor(numUsers / 20));
        if (i % progressInterval === 0 || endIndex === numUsers) {
            console.log(`📊 Created ${endIndex}/${numUsers} users (${Math.round(endIndex / numUsers * 100)}%)`.green);
        }
    }

    console.log(`✅ Successfully created ${usersData.length} users in ScyllaDB`.green);
    return usersData;
}

async function runPerformanceTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} ScyllaDB performance tests...`.cyan);
    
    // Higher concurrency for ScyllaDB
    const concurrencyLevel = Math.min(50, Math.max(10, Math.floor(numTests / 500)));
    const testPromises = [];

    for (let i = 0; i < numTests; i++) {
        const testPromise = async () => {
            const userData = usersData[Math.floor(Math.random() * usersData.length)];
            try {
                // Test 1: Save Team
                const teamData = generateTeamData(userData, Math.floor(Math.random() * 3) + 1);
                await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);

                // Test 2: Get User Teams
                await api.getUserTeams(userData, CURRENT_GAMESET);
            } catch (error) {
                console.error('Test execution error:', error.message);
            }
        };

        testPromises.push(testPromise());

        if (testPromises.length >= concurrencyLevel) {
            await Promise.all(testPromises);
            testPromises.length = 0;

            // Progress reporting
            if (numTests > 5000 && (i + 1) % Math.floor(numTests / 10) === 0) {
                console.log(`⏱️ Progress: ${i + 1}/${numTests} tests (${Math.round((i + 1) / numTests * 100)}%)`.cyan);
            }
        }
    }

    if (testPromises.length > 0) {
        await Promise.all(testPromises);
    }

    console.log('✅ ScyllaDB performance tests completed'.green);
}

function generatePerformanceReport() {
    const report = {
        timestamp: new Date().toISOString(),
        database: 'ScyllaDB',
        summary: {},
        detailedStats: {},
        scyllaSpecific: performanceStats.scyllaMetrics
    };

    Object.entries(performanceStats).forEach(([operation, times]) => {
        if (operation === 'errors' || operation === 'scyllaMetrics' || times.length === 0) return;

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

    const totalOperations = Object.values(performanceStats)
        .filter(times => Array.isArray(times) && times.length > 0)
        .reduce((sum, times) => sum + times.length, 0);

    report.errors = {
        totalErrors: performanceStats.errors.length,
        errorRate: totalOperations > 0
            ? `${((performanceStats.errors.length / totalOperations) * 100).toFixed(2)}%`
            : '0%'
    };

    return report;
}

function printPerformanceReport(report) {
    console.log('\n' + '='.repeat(80).yellow);
    console.log('FANTASY GAME SCYLLADB POC - PERFORMANCE REPORT'.bold.yellow);
    console.log('='.repeat(80).yellow);
    console.log(`Generated: ${report.timestamp}`.cyan);
    console.log(`Database: ${report.database}`.magenta);
    console.log(`Total Errors: ${report.errors.totalErrors} (${report.errors.errorRate})`.red);
    
    // ScyllaDB-specific metrics
    if (report.scyllaSpecific) {
        console.log('\nSCYLLADB-SPECIFIC METRICS:'.bold.magenta);
        console.log('-'.repeat(50).magenta);
        console.log(`Shard-aware connections: ${report.scyllaSpecific.shardAwareConnections}`.white);
    }

    console.log('\nOPERATION PERFORMANCE SUMMARY:'.bold.green);
    console.log('-'.repeat(50).green);
    Object.entries(report.summary).forEach(([operation, summary]) => {
        console.log(`${operation.toUpperCase().padEnd(20)} | ${summary}`.white);
    });

    console.log('\nDETAILED STATISTICS:'.bold.blue);
    console.log('-'.repeat(80).blue);
    console.log('Operation       Calls    Avg(ms)   Med(ms)   Min(ms)   Max(ms)   P95(ms)   P99(ms)'.bold);
    console.log('-'.repeat(80).blue);
    Object.values(report.detailedStats).forEach(stats => {
        console.log(
            `${stats.operation.padEnd(15)} ` +
            `${String(stats.totalCalls).padEnd(8)} ` +
            `${String(stats.avgTimeMs).padEnd(10)} ` +
            `${String(stats.medianTimeMs).padEnd(10)} ` +
            `${String(stats.minTimeMs).padEnd(10)} ` +
            `${String(stats.maxTimeMs).padEnd(10)} ` +
            `${String(stats.p95TimeMs).padEnd(10)} ` +
            `${String(stats.p99TimeMs).padEnd(10)}`
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
        .option('--report-file <filename>', 'Save performance report to file')
        .parse(process.argv);

    const options = program.opts();
    const numUsers = parseInt(options.users);
    const numTests = parseInt(options.tests);

    console.log('🎮 Starting Fantasy Game ScyllaDB POC (Node.js)'.bold.cyan);
    console.log(`📊 Configuration: ${numUsers} users, ${numTests} tests`.gray);

    const scyllaConn = new ScyllaDBConnection();
    if (!(await scyllaConn.connect())) {
        console.error('❌ Failed to connect to ScyllaDB. Exiting.'.red);
        process.exit(1);
    }

    try {
        const api = new FantasyGameScyllaAPI(scyllaConn);

        // Display cluster information
        const clusterStats = scyllaConn.getClusterStats();
        if (clusterStats) {
            console.log(`🏁 Cluster: ${clusterStats.healthyHosts}/${clusterStats.totalHosts} nodes healthy`.green);
            console.log(`🌍 Datacenters: ${clusterStats.datacenters.join(', ')}`.gray);
        }

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

        console.log('⏱️ Starting ScyllaDB performance tests...'.cyan);
        const startTime = Date.now();
        await runPerformanceTests(api, usersData, numTests);
        const totalTestTime = Date.now() - startTime;

        const report = generatePerformanceReport();
        report.testDurationSeconds = Math.round(totalTestTime / 1000 * 100) / 100;
        report.throughputOpsPerSecond = Math.round((numTests / (totalTestTime / 1000)) * 100) / 100;

        printPerformanceReport(report);

        if (options.reportFile) {
            await fs.writeFile(options.reportFile, JSON.stringify(report, null, 2));
            console.log(`💾 Performance report saved to ${options.reportFile}`.green);
        }

        console.log('🎉 ScyllaDB POC testing completed successfully'.bold.green);
    } catch (error) {
        console.error('❌ ScyllaDB POC testing failed:'.red, error.message);
        throw error;
    } finally {
        await scyllaConn.shutdown();
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

if (require.main === module) {
    main().catch(error => {
        console.error('💥 Fatal error:'.red, error);
        process.exit(1);
    });
}

module.exports = { main, FantasyGameScyllaAPI, ScyllaDBConnection };
