#!/usr/bin/env node

/**
 * Fantasy Game CockroachDB POC Testing Script - Node.js Version
 * =============================================================
 * 
 * This script tests core fantasy game APIs against CockroachDB to evaluate
 * performance compared to Cassandra and PostgreSQL. It includes realistic 
 * football data, comprehensive performance metrics, and shard-aware routing.
 * 
 * Usage:
 * node fantasy-game-cockroachdb-poc.js --users 1000 --tests 100
 */

const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const path = require('path');
const { program } = require('commander');
const colors = require('colors');
const crypto = require('crypto');

// ====================================================================
// COCKROACHDB CONFIGURATION & SHARD ROUTING
// ====================================================================

const COCKROACH_NODES = [
    { host: 'localhost', port: 26257, shard: 0, name: 'roach1' },
    { host: 'localhost', port: 26258, shard: 1, name: 'roach2' },
    { host: 'localhost', port: 26259, shard: 2, name: 'roach3' }
];

const COCKROACH_CONFIG = {
    database: 'fantasy_game',
    user: 'root',
    password: '', // CockroachDB insecure mode
    ssl: false,
    max: 20, // Connection pool size
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
    query_timeout: 20000
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
    errors: [],
    cockroachMetrics: {
        shardDistribution: { 0: 0, 1: 0, 2: 0 },
        partitionDistribution: {},
        connectionErrors: 0,
        shardSwitches: 0
    }
};

// ====================================================================
// SHARD ROUTER CLASS
// ====================================================================

class CockroachShardRouter {
    constructor() {
        this.connections = new Map();
        this.currentConnections = new Map();
    }

    // Hash function matching CockroachDB's fnv32
    calculatePartitionId(sourceId) {
        let hash = 2166136261; // FNV-1a offset basis
        for (let i = 0; i < sourceId.length; i++) {
            hash ^= sourceId.charCodeAt(i);
            hash *= 16777619; // FNV-1a prime
        }
        return Math.abs(hash) % 30; // 30 total partitions (0-29)
    }

    getShardForPartition(partitionId) {
        // Map partition_id to physical shard
        if (partitionId >= 0 && partitionId <= 9) return 0;    // Shard 0: partitions 0-9
        if (partitionId >= 10 && partitionId <= 19) return 1;  // Shard 1: partitions 10-19  
        if (partitionId >= 20 && partitionId <= 29) return 2;  // Shard 2: partitions 20-29
        throw new Error(`Invalid partition_id: ${partitionId}`);
    }

    getConnectionInfoForSourceId(sourceId) {
        const partitionId = this.calculatePartitionId(sourceId);
        const shardId = this.getShardForPartition(partitionId);
        const nodeInfo = COCKROACH_NODES[shardId];
        
        // Track metrics
        performanceStats.cockroachMetrics.shardDistribution[shardId]++;
        performanceStats.cockroachMetrics.partitionDistribution[partitionId] = 
            (performanceStats.cockroachMetrics.partitionDistribution[partitionId] || 0) + 1;
        
        return {
            ...nodeInfo,
            partitionId,
            connectionString: this.buildConnectionString(nodeInfo)
        };
    }

    buildConnectionString(nodeInfo) {
        return `postgresql://root@${nodeInfo.host}:${nodeInfo.port}/${COCKROACH_CONFIG.database}?sslmode=disable`;
    }

    async getConnection(sourceId) {
        const connInfo = this.getConnectionInfoForSourceId(sourceId);
        const key = `shard_${connInfo.shard}`;
        
        if (!this.connections.has(key)) {
            const pool = new Pool({
                ...COCKROACH_CONFIG,
                host: connInfo.host,
                port: connInfo.port,
                connectionString: connInfo.connectionString
            });
            
            this.connections.set(key, {
                pool,
                partitionId: connInfo.partitionId,
                shardId: connInfo.shard,
                nodeInfo: connInfo
            });
        }
        
        return this.connections.get(key);
    }

    async closeAllConnections() {
        for (const [key, conn] of this.connections) {
            await conn.pool.end();
        }
        this.connections.clear();
    }
}

// ====================================================================
// REALISTIC FANTASY FOOTBALL DATA (Same as Cassandra POC)
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
// COCKROACHDB CONNECTION CLASS
// ====================================================================

class CockroachDBConnection {
    constructor() {
        this.shardRouter = new CockroachShardRouter();
        this.isConnected = false;
    }

    async connect() {
        try {
            console.log('🔗 Connecting to CockroachDB cluster...'.cyan);
            
            // Test connectivity to all nodes
            for (const node of COCKROACH_NODES) {
                const testPool = new Pool({
                    ...COCKROACH_CONFIG,
                    host: node.host,
                    port: node.port,
                    max: 1
                });
                
                try {
                    const client = await testPool.connect();
                    const result = await client.query('SELECT version()');
                    console.log(`✅ Connected to ${node.name} (${node.host}:${node.port})`.green);
                    client.release();
                    await testPool.end();
                } catch (error) {
                    console.error(`❌ Failed to connect to ${node.name}:`.red, error.message);
                    return false;
                }
            }
            
            this.isConnected = true;
            console.log('🎯 CockroachDB cluster connection established'.green);
            return true;
        } catch (error) {
            console.error('❌ Failed to connect to CockroachDB cluster:'.red, error.message);
            return false;
        }
    }

    async executeFunction(sourceId, functionName, params = []) {
        try {
            const connection = await this.shardRouter.getConnection(sourceId);
            const client = await connection.pool.connect();
            
            try {
                const paramPlaceholders = params.map((_, i) => `$${i + 1}`).join(', ');
                const query = `SELECT ${functionName}(${paramPlaceholders})`;
                const result = await client.query(query, params);
                
                return {
                    success: true,
                    data: result.rows[0] ? Object.values(result.rows[0])[0] : null,
                    partitionId: connection.partitionId,
                    shardId: connection.shardId
                };
            } finally {
                client.release();
            }
        } catch (error) {
            performanceStats.cockroachMetrics.connectionErrors++;
            throw error;
        }
    }

    async executeQuery(sourceId, query, params = []) {
        try {
            const connection = await this.shardRouter.getConnection(sourceId);
            const client = await connection.pool.connect();
            
            try {
                const result = await client.query(query, params);
                return {
                    success: true,
                    rows: result.rows,
                    partitionId: connection.partitionId,
                    shardId: connection.shardId
                };
            } finally {
                client.release();
            }
        } catch (error) {
            performanceStats.cockroachMetrics.connectionErrors++;
            throw error;
        }
    }

    async shutdown() {
        if (this.shardRouter) {
            await this.shardRouter.closeAllConnections();
            console.log('🔌 Disconnected from CockroachDB cluster'.yellow);
        }
    }

    getShardStats() {
        return {
            shardDistribution: performanceStats.cockroachMetrics.shardDistribution,
            partitionDistribution: performanceStats.cockroachMetrics.partitionDistribution,
            connectionErrors: performanceStats.cockroachMetrics.connectionErrors,
            totalOperations: Object.values(performanceStats.cockroachMetrics.shardDistribution)
                .reduce((sum, count) => sum + count, 0)
        };
    }
}

// ====================================================================
// UTILITY FUNCTIONS
// ====================================================================

function calculatePartitionId(sourceId) {
    // Use the same hash function as CockroachDB shard router
    const router = new CockroachShardRouter();
    return router.calculatePartitionId(sourceId);
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
    // Select 11 main players + 4 reserves
    const shuffledPlayers = [...FOOTBALL_PLAYERS].sort(() => 0.5 - Math.random());
    const mainPlayers = shuffledPlayers.slice(0, 11);
    const reservePlayers = shuffledPlayers.slice(11, 15);
    
    const inplayEntities = mainPlayers.map((player, idx) => ({
        entity_id: player.id,
        skill_id: player.skillId,
        order: idx + 1
    }));
    
    const reservedEntities = reservePlayers.map((player, idx) => ({
        entity_id: player.id,
        skill_id: player.skillId,
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
        inplayEntities,
        reservedEntities,
        boosterId: Math.floor(Math.random() * 3) + 1,
        boosterPlayerId: mainPlayers[Math.floor(Math.random() * mainPlayers.length)].id,
        transfersAllowed: 5,
        transfersMade: Math.floor(Math.random() * 4),
        transfersLeft: function () { return this.transfersAllowed - this.transfersMade; }
    };
}

function logPerformance(operation, duration, success = true, additionalData = {}) {
    if (success) {
        performanceStats[operation].push(duration);
    } else {
        performanceStats.errors.push({
            operation,
            duration,
            timestamp: new Date().toISOString(),
            ...additionalData
        });
    }
}

// ====================================================================
// FANTASY GAME API CLASS
// ====================================================================

class FantasyGameCockroachAPI {
    constructor(cockroachConn) {
        this.db = cockroachConn;
    }

    async userLogin(sourceId, deviceId, loginPlatformSource, additionalData = {}) {
        const startTime = Date.now();
        try {
            const requestData = {
                source_id: sourceId,
                device_id: deviceId,
                login_platform_source: loginPlatformSource,
                first_name: additionalData.firstName || 'User',
                last_name: additionalData.lastName || 'Player',
                user_name: additionalData.userName || `player_${sourceId}`,
                user_properties: additionalData.user_properties || [
                    { key: 'residence_country', value: 'US' },
                    { key: 'subscription_active', value: '1' },
                    { key: 'profile_pic_url', value: `https://example.com/pic_${sourceId}.jpg` }
                ],
                user_preferences: additionalData.user_preferences || [
                    { preference: 'country', value: 1 },
                    { preference: 'team_1', value: 1 },
                    { preference: 'tnc', value: 1 }
                ]
            };

            const result = await this.db.executeFunction(
                sourceId,
                'game_user.user_login',
                [JSON.stringify(requestData)]
            );

            const duration = Date.now() - startTime;
            logPerformance('userLogin', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
            });

            return {
                success: true,
                data: result.data,
                shardId: result.shardId,
                partitionId: result.partitionId
            };
        } catch (error) {
            const duration = Date.now() - startTime;
            logPerformance('userLogin', duration, false, { error: error.message });
            console.error('User login failed:', error.message);
            return { success: false, error: error.message };
        }
    }

    async getUserProfile(sourceId, userId) {
        const startTime = Date.now();
        try {
            const partitionId = calculatePartitionId(sourceId);
            const query = `
                SELECT user_id, source_id, user_guid, first_name, last_name, user_name,
                       device_id, login_platform_source, profanity_status,
                       user_properties, user_preferences, created_date
                FROM game_user.users 
                WHERE partition_id = $1 AND user_id = $2
            `;

            const result = await this.db.executeQuery(sourceId, query, [partitionId, userId]);

            const duration = Date.now() - startTime;
            logPerformance('getUserProfile', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
            });

            if (result.rows.length === 0) {
                return { success: false, error: 'User not found' };
            }

            const user = result.rows[0];
            return {
                success: true,
                data: {
                    user_id: user.user_id,
                    source_id: user.source_id,
                    user_guid: user.user_guid,
                    first_name: user.first_name,
                    last_name: user.last_name,
                    user_name: user.user_name,
                    device_id: user.device_id,
                    login_platform_source: user.login_platform_source,
                    profanity_status: user.profanity_status,
                    user_properties: user.user_properties,
                    user_preferences: user.user_preferences,
                    created_date: user.created_date
                },
                shardId: result.shardId,
                partitionId: result.partitionId
            };
        } catch (error) {
            const duration = Date.now() - startTime;
            logPerformance('getUserProfile', duration, false, { error: error.message });
            console.error('Get user profile failed:', error.message);
            return { success: false, error: error.message };
        }
    }

    async saveTeam(userData, teamData, gamesetId, gamedayId, fantasyType = 1) {
        const startTime = Date.now();
        try {
            const requestData = {
                device_id: userData.deviceId,
                event_group: {
                    phase_id: 1,
                    gameset_id: gamesetId,
                    gameday_id: gamedayId
                },
                captain_id: teamData.captainPlayerId,
                vice_captain_id: teamData.viceCaptainPlayerId,
                booster: {
                    booster_id: teamData.boosterId,
                    entity_id: teamData.boosterPlayerId
                },
                inplay_entities: teamData.inplayEntities,
                reserved_entities: teamData.reservedEntities,
                team_name: teamData.teamName
            };

            const result = await this.db.executeFunction(
                userData.sourceId,
                'gameplay.save_team',
                [JSON.stringify(requestData), userData.userId, userData.partitionId]
            );

            const duration = Date.now() - startTime;
            logPerformance('saveTeam', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
            });

            return {
                success: true,
                data: result.data,
                shardId: result.shardId,
                partitionId: result.partitionId
            };
        } catch (error) {
            const duration = Date.now() - startTime;
            logPerformance('saveTeam', duration, false, { error: error.message });
            console.error('Save team failed:', error.message);
            return { success: false, error: error.message };
        }
    }

    async transferTeam(userData, teamNo, entitiesIn, entitiesOut, gamesetId, gamedayId, 
                      captainId, viceCaptainId, boosterId, boosterPlayerId, fantasyType = 1) {
        const startTime = Date.now();
        try {
            const requestData = {
                device_id: userData.deviceId,
                event_group: {
                    phase_id: 1,
                    gameset_id: gamesetId,
                    gameday_id: gamedayId
                },
                team_no: teamNo,
                captain_id: captainId,
                vice_captain_id: viceCaptainId,
                booster: {
                    booster_id: boosterId,
                    entity_id: boosterPlayerId
                },
                entities_in: entitiesIn,
                entities_out: entitiesOut
            };

            const result = await this.db.executeFunction(
                userData.sourceId,
                'gameplay.transfer_team',
                [JSON.stringify(requestData), userData.userId, userData.partitionId]
            );

            const duration = Date.now() - startTime;
            logPerformance('transferTeam', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
            });

            return {
                success: true,
                data: result.data,
                shardId: result.shardId,
                partitionId: result.partitionId
            };
        } catch (error) {
            const duration = Date.now() - startTime;
            logPerformance('transferTeam', duration, false, { error: error.message });
            console.error('Transfer team failed:', error.message);
            return { success: false, error: error.message };
        }
    }

    async getUserTeams(userData, gamesetId) {
        const startTime = Date.now();
        try {
            const query = `
                SELECT user_id, team_no, team_name, profanity_status, 
                       team_valuation, remaining_budget, captain_player_id, vice_captain_player_id,
                       team_players, transfers_allowed, transfers_made, transfers_left,
                       booster_id, booster_player_id, team_json
                FROM gameplay.user_team_detail
                WHERE partition_id = $1 AND user_id = $2 AND season_id = $3
                ORDER BY team_no, gameset_id DESC, gameday_id DESC
            `;

            const result = await this.db.executeQuery(
                userData.sourceId, 
                query, 
                [userData.partitionId, userData.userId, CURRENT_SEASON]
            );

            const duration = Date.now() - startTime;
            logPerformance('getUserTeams', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
            });

            // Group by team_no and get latest record for each team
            const teamsMap = new Map();
            result.rows.forEach(row => {
                if (!teamsMap.has(row.team_no)) {
                    teamsMap.set(row.team_no, row);
                }
            });

            const teams = Array.from(teamsMap.values()).map(row => {
                const teamJson = row.team_json || {};
                const inplayEntities = teamJson.inplay_entities || [];
                const reservedEntities = teamJson.reserved_entities || [];
                
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
                    boosters: row.booster_id ? [{ 
                        boosterId: row.booster_id, 
                        playerId: row.booster_player_id 
                    }] : [],
                    formation,
                    budget: {
                        limit: 100,
                        utilized: parseFloat(row.team_valuation || 0),
                        left: parseFloat(row.remaining_budget || 0)
                    },
                    inplayEntities,
                    reservedEntities,
                    points: "0", // Would be calculated from actual game data
                    rank: 0
                };
            });

            return {
                success: true,
                data: {
                    teamCreatedCount: teams.length,
                    maxTeamAllowed: 5,
                    rank: teams.length > 0 ? teams[0].rank : 0,
                    totalPoints: "0",
                    teams
                },
                shardId: result.shardId,
                partitionId: result.partitionId
            };
        } catch (error) {
            const duration = Date.now() - startTime;
            logPerformance('getUserTeams', duration, false, { error: error.message });
            console.error('Get user teams failed:', error.message);
            return { success: false, error: error.message };
        }
    }
}

// ====================================================================
// TEST DATA GENERATION & POPULATION
// ====================================================================

async function populateTestData(api, numUsers) {
    console.log(`🔄 Generating test data for ${numUsers} users in CockroachDB...`.cyan);
    const usersData = [];
    const batchSize = Math.min(50, Math.max(5, Math.floor(numUsers / 100))); // Smaller batches for CockroachDB

    for (let i = 0; i < numUsers; i += batchSize) {
        const batch = [];
        const endIndex = Math.min(i + batchSize, numUsers);
        
        for (let userId = i + 1; userId <= endIndex; userId++) {
            const userData = generateUserData(userId);
            usersData.push(userData);

            const userPromise = async () => {
                try {
                    const additionalData = {
                        firstName: userData.firstName,
                        lastName: userData.lastName,
                        userName: userData.userName,
                        user_properties: [
                            { key: 'residence_country', value: ['US', 'UK', 'IN', 'CA'][Math.floor(Math.random() * 4)] },
                            { key: 'subscription_active', value: '1' },
                            { key: 'profile_pic_url', value: `https://example.com/pic_${userId}.jpg` }
                        ],
                        user_preferences: [
                            { preference: 'country', value: Math.floor(Math.random() * 5) + 1 },
                            { preference: 'team_1', value: Math.floor(Math.random() * 20) + 1 },
                            { preference: 'team_2', value: Math.floor(Math.random() * 20) + 1 },
                            { preference: 'tnc', value: 1 }
                        ]
                    };

                    await api.userLogin(userData.sourceId, userData.deviceId, userData.loginPlatformSource, additionalData);
                } catch (error) {
                    console.error(`Failed to create user ${userId}:`, error.message);
                }
            };

            batch.push(userPromise());
        }

        // Execute batch with controlled concurrency
        await Promise.all(batch);

        // Progress indicator
        const progressInterval = Math.max(100, Math.floor(numUsers / 50));
        if (i % progressInterval === 0 || endIndex === numUsers) {
            console.log(`📊 Created ${endIndex}/${numUsers} users (${Math.round(endIndex / numUsers * 100)}%)`.green);
        }
    }

    console.log(`✅ Successfully created ${usersData.length} users in CockroachDB`.green);
    return usersData;
}

// ====================================================================
// PERFORMANCE TESTING
// ====================================================================

async function runPerformanceTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} CockroachDB performance tests...`.cyan);
    const concurrencyLevel = Math.min(15, Math.max(3, Math.floor(numTests / 1000))); // Lower concurrency for CockroachDB
    const testPromises = [];

    for (let i = 0; i < numTests; i++) {
        const testPromise = async () => {
            const userData = usersData[Math.floor(Math.random() * usersData.length)];
            try {
                // Test 1: User Login
                const loginResult = await api.userLogin(userData.sourceId, userData.deviceId, userData.loginPlatformSource);
                
                if (loginResult.success) {
                    // Test 2: Get User Profile
                    await api.getUserProfile(userData.sourceId, userData.userId);
                    
                    // Test 3: Save Team
                    const teamData = generateTeamData(userData, Math.floor(Math.random() * 3) + 1);
                    const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);
                    
                    // Test 4: Get User Teams
                    await api.getUserTeams(userData, CURRENT_GAMESET);
                    
                    // Test 5: Transfer Team (10% of tests)
                    if (Math.random() < 0.1 && saveResult.success) {
                        const entitiesIn = [{ entity_id: 1015, skill_id: 4, order: 1 }]; // Haaland
                        const entitiesOut = [{ entity_id: 1003, skill_id: 4, order: 1 }]; // Kane
                        await api.transferTeam(
                            userData, teamData.teamNo, entitiesIn, entitiesOut,
                            CURRENT_GAMESET, CURRENT_GAMEDAY,
                            teamData.captainPlayerId, teamData.viceCaptainPlayerId,
                            teamData.boosterId, teamData.boosterPlayerId
                        );
                    }
                }
            } catch (error) {
                console.error('Test execution error:', error.message);
            }
        };

        testPromises.push(testPromise());

        // Control concurrency
        if (testPromises.length >= concurrencyLevel) {
            await Promise.all(testPromises);
            testPromises.length = 0;

            // Progress reporting
            if (numTests > 5000 && (i + 1) % Math.floor(numTests / 20) === 0) {
                console.log(`⏱️ Progress: ${i + 1}/${numTests} tests (${Math.round((i + 1) / numTests * 100)}%)`.cyan);
            }
        }
    }

    // Execute remaining tests
    if (testPromises.length > 0) {
        await Promise.all(testPromises);
    }

    console.log('✅ CockroachDB performance tests completed'.green);
}

// ====================================================================
// PERFORMANCE REPORTING
// ====================================================================

function generatePerformanceReport(cockroachConn) {
    const report = {
        timestamp: new Date().toISOString(),
        database: 'CockroachDB',
        summary: {},
        detailedStats: {},
        shardStats: cockroachConn.getShardStats()
    };

    Object.entries(performanceStats).forEach(([operation, times]) => {
        if (operation === 'errors' || operation === 'cockroachMetrics' || times.length === 0) return;

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
        errorRate: totalOperations > 0
            ? `${((performanceStats.errors.length / totalOperations) * 100).toFixed(2)}%`
            : '0%'
    };

    return report;
}

function printPerformanceReport(report) {
    console.log('\n' + '='.repeat(80).yellow);
    console.log('FANTASY GAME COCKROACHDB POC - PERFORMANCE REPORT'.bold.yellow);
    console.log('='.repeat(80).yellow);
    console.log(`Generated: ${report.timestamp}`.cyan);
    console.log(`Database: ${report.database}`.magenta);
    console.log(`Total Errors: ${report.errors.totalErrors} (${report.errors.errorRate})`.red);

    // CockroachDB-specific metrics
    console.log('\nCOCKROACHDB SHARD DISTRIBUTION:'.bold.magenta);
    console.log('-'.repeat(50).magenta);
    Object.entries(report.shardStats.shardDistribution).forEach(([shardId, count]) => {
        const percentage = ((count / report.shardStats.totalOperations) * 100).toFixed(1);
        console.log(`Shard ${shardId}: ${count} operations (${percentage}%)`.white);
    });

    console.log(`Connection Errors: ${report.shardStats.connectionErrors}`.white);
    console.log(`Total Operations: ${report.shardStats.totalOperations}`.white);

    console.log('\nOPERATION PERFORMANCE SUMMARY:'.bold.green);
    console.log('-'.repeat(50).green);
    Object.entries(report.summary).forEach(([operation, summary]) => {
        console.log(`${operation.toUpperCase().padEnd(20)} | ${summary}`.white);
    });

    console.log('\nDETAILED STATISTICS:'.bold.blue);
    console.log('-'.repeat(80).blue);
    console.log('Operation       Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)'.bold);
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

    console.log('🎮 Starting Fantasy Game CockroachDB POC (Node.js)'.bold.cyan);
    console.log(`📊 Configuration: ${numUsers} users, ${numTests} tests`.gray);

    // Connect to CockroachDB
    const cockroachConn = new CockroachDBConnection();
    if (!(await cockroachConn.connect())) {
        console.error('❌ Failed to connect to CockroachDB. Exiting.'.red);
        process.exit(1);
    }

    try {
        const api = new FantasyGameCockroachAPI(cockroachConn);

        let usersData;
        if (!options.skipData) {
            if (numUsers > 5000) {
                console.log(`⚠️ WARNING: Creating ${numUsers} users will take significant time. Consider using --skip-data for large tests.`.yellow);
            }
            usersData = await populateTestData(api, numUsers);
        } else {
            console.log(`📊 Generating user data structures for ${numUsers} users (no database inserts)...`.cyan);
            usersData = Array.from({ length: numUsers }, (_, i) => generateUserData(i + 1));
            console.log(`✅ Generated ${usersData.length} user data structures`.green);
        }

        // Run performance tests
        console.log('⏱️ Starting CockroachDB performance tests...'.cyan);
        const startTime = Date.now();
        await runPerformanceTests(api, usersData, numTests);
        const totalTestTime = Date.now() - startTime;

        // Generate and display report
        const report = generatePerformanceReport(cockroachConn);
        report.testDurationSeconds = Math.round(totalTestTime / 1000 * 100) / 100;
        report.throughputOpsPerSecond = Math.round((numTests / (totalTestTime / 1000)) * 100) / 100;

        printPerformanceReport(report);

        // Save report if requested
        if (options.reportFile) {
            await fs.writeFile(options.reportFile, JSON.stringify(report, null, 2));
            console.log(`💾 Performance report saved to ${options.reportFile}`.green);
        }

        console.log('🎉 CockroachDB POC testing completed successfully'.bold.green);
    } catch (error) {
        console.error('❌ CockroachDB POC testing failed:'.red, error.message);
        throw error;
    } finally {
        await cockroachConn.shutdown();
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

module.exports = { main, FantasyGameCockroachAPI, CockroachDBConnection };
