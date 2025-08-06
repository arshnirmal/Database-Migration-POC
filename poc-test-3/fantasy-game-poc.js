#!/usr/bin/env node

/**
 * Fantasy Game CockroachDB POC - Complete Fixed Version
 * ====================================================
 * 
 * FIXES APPLIED:
 * 1. ✅ Unique team names to prevent constraint violations
 * 2. ✅ Robust error handling in test sequence
 * 3. ✅ All 5 APIs properly tested and tracked
 * 4. ✅ Direct SQL queries (no database functions)
 * 5. ✅ Proper shard routing and performance tracking
 * 
 * APIs: userLogin, getUserProfile, saveTeam, getUserTeams, transferTeam
 */

const { Pool } = require('pg');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const { program } = require('commander');
const colors = require('colors');

// ====================================================================
// CONFIGURATION & SETUP
// ====================================================================

const COCKROACH_NODES = [
    { host: 'localhost', port: 26257, shard: 0, name: 'roach1' },
    { host: 'localhost', port: 26258, shard: 1, name: 'roach2' },
    { host: 'localhost', port: 26259, shard: 2, name: 'roach3' }
];

const COCKROACH_CONFIG = {
    database: 'fantasy_game',
    user: 'root',
    password: '',
    ssl: false,
    max: 20,
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
        connectionErrors: 0
    }
};

// ====================================================================
// SHARD ROUTER CLASS
// ====================================================================

class CockroachShardRouter {
    constructor() {
        this.connections = new Map();
    }

    calculatePartitionId(sourceId) {
        let hash = 2166136261; // FNV-1a offset basis
        for (let i = 0; i < sourceId.length; i++) {
            hash ^= sourceId.charCodeAt(i);
            hash *= 16777619; // FNV-1a prime
        }
        return Math.abs(hash) % 30; // 30 total partitions (0-29)
    }

    getShardForPartition(partitionId) {
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
// ENHANCED FANTASY FOOTBALL DATA
// ====================================================================

const FOOTBALL_PLAYERS = [
    // Goalkeepers (skillId: 5)
    { id: 1011, name: "Alisson Becker", skillId: 5, price: 5.5, team: "Liverpool" },
    { id: 1016, name: "Thibaut Courtois", skillId: 5, price: 5.0, team: "Real Madrid" },
    { id: 1021, name: "Gianluigi Donnarumma", skillId: 5, price: 4.5, team: "PSG" },
    { id: 1022, name: "Ederson", skillId: 5, price: 5.0, team: "Man City" },
    
    // Defenders (skillId: 1)
    { id: 1004, name: "Virgil van Dijk", skillId: 1, price: 6.5, team: "Liverpool" },
    { id: 1007, name: "Sergio Ramos", skillId: 1, price: 5.0, team: "PSG" },
    { id: 1020, name: "João Cancelo", skillId: 1, price: 7.0, team: "Man City" },
    { id: 1023, name: "Marquinhos", skillId: 1, price: 5.5, team: "PSG" },
    { id: 1024, name: "Ruben Dias", skillId: 1, price: 6.0, team: "Man City" },
    { id: 1025, name: "Andrew Robertson", skillId: 1, price: 6.5, team: "Liverpool" },
    { id: 1026, name: "Trent Alexander-Arnold", skillId: 1, price: 7.5, team: "Liverpool" },
    
    // Midfielders (skillId: 2)
    { id: 1001, name: "Kevin De Bruyne", skillId: 2, price: 12.5, team: "Man City" },
    { id: 1006, name: "N'Golo Kanté", skillId: 2, price: 5.5, team: "Al-Ittihad" },
    { id: 1008, name: "Luka Modrić", skillId: 2, price: 8.5, team: "Real Madrid" },
    { id: 1012, name: "Mason Mount", skillId: 2, price: 6.5, team: "Man United" },
    { id: 1014, name: "Bruno Fernandes", skillId: 2, price: 8.5, team: "Man United" },
    { id: 1018, name: "Pedri", skillId: 2, price: 6.0, team: "Barcelona" },
    
    // Forwards (skillId: 3)
    { id: 1002, name: "Mohamed Salah", skillId: 3, price: 13.0, team: "Liverpool" },
    { id: 1005, name: "Sadio Mané", skillId: 3, price: 10.0, team: "Al Nassr" },
    { id: 1010, name: "Kylian Mbappé", skillId: 3, price: 12.0, team: "PSG" },
    { id: 1013, name: "Phil Foden", skillId: 3, price: 8.0, team: "Man City" },
    { id: 1019, name: "Vinicius Jr.", skillId: 3, price: 9.5, team: "Real Madrid" },
    
    // Strikers (skillId: 4)
    { id: 1003, name: "Harry Kane", skillId: 4, price: 11.5, team: "Bayern Munich" },
    { id: 1009, name: "Robert Lewandowski", skillId: 4, price: 9.0, team: "Barcelona" },
    { id: 1015, name: "Erling Haaland", skillId: 4, price: 15.0, team: "Man City" },
    { id: 1017, name: "Karim Benzema", skillId: 4, price: 10.0, team: "Al-Ittihad" }
];

const TEAM_NAMES = [
    "Thunderbolts United", "Lightning Strikers", "Phoenix Rising", "Dragon Warriors",
    "Viper Squad", "Eagle Force", "Titan Crushers", "Storm Riders", "Fire Eagles",
    "Ice Wolves", "Shadow Hunters", "Golden Arrows", "Silver Bullets", "Crimson Lions"
];

const SOURCE_PLATFORMS = [
    { id: 1, name: "facebook", prefix: "fb_" },
    { id: 2, name: "google", prefix: "gg_" },
    { id: 3, name: "apple", prefix: "ap_" },
    { id: 4, name: "twitter", prefix: "tw_" }
];

const FIRST_NAMES = ["James", "John", "Robert", "Michael", "William", "David", "Richard", "Joseph"];
const LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"];

// ====================================================================
// BUSINESS LOGIC & VALIDATION FUNCTIONS
// ====================================================================

const FORMATION_RULES = {
    1: { min: 3, max: 5 }, // Defenders
    2: { min: 3, max: 5 }, // Midfielders  
    3: { min: 1, max: 3 }, // Forwards
    4: { min: 1, max: 3 }, // Strikers
    5: { min: 1, max: 1 }  // Goalkeepers
};

function validateFormation(players) {
    const skillCounts = {};
    const issues = [];
    
    players.forEach(player => {
        skillCounts[player.skill_id] = (skillCounts[player.skill_id] || 0) + 1;
    });
    
    if (players.length !== 11) {
        issues.push(`Team must have exactly 11 players, found ${players.length}`);
    }
    
    let formationValid = true;
    Object.entries(FORMATION_RULES).forEach(([skillId, rules]) => {
        const count = skillCounts[skillId] || 0;
        if (count < rules.min || count > rules.max) {
            issues.push(`Invalid ${skillId} count: ${count} (required: ${rules.min}-${rules.max})`);
            formationValid = false;
        }
    });
    
    return {
        valid: formationValid && players.length === 11,
        issues,
        currentFormation: skillCounts
    };
}

function validateBudget(players, budgetLimit = 100.0) {
    let totalCost = 0;
    players.forEach(player => {
        const playerData = FOOTBALL_PLAYERS.find(p => p.id === player.entity_id);
        totalCost += playerData ? playerData.price : 5.0;
    });
    
    return {
        valid: totalCost <= budgetLimit,
        totalCost,
        remainingBudget: Math.max(0, budgetLimit - totalCost),
        budgetLimit
    };
}

function buildUserResponse(user, currentTime) {
    return {
        data: {
            device_id: user.device_id,
            guid: user.user_guid,
            source_id: user.source_id,
            user_name: user.user_name,
            first_name: user.first_name,
            last_name: user.last_name,
            profanity_status: user.profanity_status,
            preferences_saved: true,
            login_platform_source: user.login_platform_source,
            user_session: {
                game_token: '<jwt_token>',
                created_at: currentTime,
                expires_at: new Date(currentTime.getTime() + 24 * 60 * 60 * 1000)
            },
            user_properties: user.user_properties || [],
            user_preferences: user.user_preferences || []
        },
        meta: {
            retval: 1,
            message: 'OK',
            timestamp: currentTime
        }
    };
}

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

    async executeTransaction(sourceId, operations) {
        const connection = await this.shardRouter.getConnection(sourceId);
        const client = await connection.pool.connect();
        
        try {
            await client.query('BEGIN');
            
            const results = [];
            for (const operation of operations) {
                const result = await client.query(operation.query, operation.params);
                results.push(result);
            }
            
            await client.query('COMMIT');
            return {
                success: true,
                results,
                partitionId: connection.partitionId,
                shardId: connection.shardId
            };
        } catch (error) {
            await client.query('ROLLBACK');
            throw error;
        } finally {
            client.release();
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
    const router = new CockroachShardRouter();
    return router.calculatePartitionId(sourceId);
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
        partitionId: calculatePartitionId(sourceId)
    };
}

// ✅ FIXED: Generate unique team names to prevent constraint violations
function generateTeamData(userData, teamNo) {
    // Generate valid team composition
    const goalkeepers = FOOTBALL_PLAYERS.filter(p => p.skillId === 5).slice(0, 1);
    const defenders = FOOTBALL_PLAYERS.filter(p => p.skillId === 1).slice(0, 4);
    const midfielders = FOOTBALL_PLAYERS.filter(p => p.skillId === 2).slice(0, 4);
    const forwards = FOOTBALL_PLAYERS.filter(p => p.skillId === 3).slice(0, 1);
    const strikers = FOOTBALL_PLAYERS.filter(p => p.skillId === 4).slice(0, 1);
    
    const mainPlayers = [...goalkeepers, ...defenders, ...midfielders, ...forwards, ...strikers];
    const reservePlayers = FOOTBALL_PLAYERS.filter(p => !mainPlayers.includes(p)).slice(0, 4);
    
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
        // ✅ FIXED: Create unique team name using timestamp and user ID
        teamName: `${TEAM_NAMES[Math.floor(Math.random() * TEAM_NAMES.length)]} ${Date.now()}_${userData.userId}`,
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
// FANTASY GAME API CLASS (ALL 5 APIs - Direct SQL)
// ====================================================================

class FantasyGameCockroachAPI {
    constructor(cockroachConn) {
        this.db = cockroachConn;
    }

    calculatePartitionId(sourceId) {
        let hash = 2166136261; // FNV-1a offset basis
        for (let i = 0; i < sourceId.length; i++) {
            hash ^= sourceId.charCodeAt(i);
            hash *= 16777619; // FNV-1a prime
        }
        return Math.abs(hash) % 30;
    }

    async userLogin(sourceId, deviceId, loginPlatformSource, additionalData = {}) {
        const startTime = Date.now();
        try {
            const partitionId = this.calculatePartitionId(sourceId);
            
            // DIRECT SQL: Check if user exists
            const checkUserQuery = `
                SELECT user_id, user_guid, first_name, last_name, user_name,
                       device_id, login_platform_source, profanity_status,
                       user_properties, user_preferences, created_date
                FROM game_user.users 
                WHERE source_id = $1 AND partition_id = $2
            `;
            
            const existingUserResult = await this.db.executeQuery(
                sourceId, checkUserQuery, [sourceId, partitionId]
            );
            
            const currentTime = new Date();
            
            if (existingUserResult.rows.length > 0) {
                // User exists - return user details
                const user = existingUserResult.rows[0];
                const response = buildUserResponse({
                    device_id: deviceId,
                    user_guid: user.user_guid,
                    source_id: sourceId,
                    user_name: user.user_name,
                    first_name: user.first_name,
                    last_name: user.last_name,
                    profanity_status: user.profanity_status,
                    login_platform_source: user.login_platform_source,
                    user_properties: user.user_properties,
                    user_preferences: user.user_preferences
                }, currentTime);
                
                const duration = Date.now() - startTime;
                logPerformance('userLogin', duration, true, { 
                    shardId: existingUserResult.shardId, 
                    partitionId: existingUserResult.partitionId 
                });
                
                return {
                    success: true,
                    data: response,
                    userId: user.user_id, // ✅ FIXED: Return actual user_id
                    shardId: existingUserResult.shardId,
                    partitionId: existingUserResult.partitionId
                };
            } else {
                // DIRECT SQL: Create new user
                const insertUserQuery = `
                    INSERT INTO game_user.users (
                        source_id, first_name, last_name, user_name, device_id, device_version,
                        login_platform_source, created_date, updated_date, registered_date,
                        partition_id, opt_in, user_properties, user_preferences, profanity_status
                    ) VALUES (
                        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
                    ) RETURNING user_id, user_guid, first_name, last_name, user_name
                `;
                
                const defaultUserData = {
                    first_name: additionalData.firstName || 'User',
                    last_name: additionalData.lastName || 'Player',
                    user_name: additionalData.userName || `player_${sourceId}`,
                    device_version: '1.0',
                    opt_in: JSON.stringify({ email: true, sms: false }),
                    user_properties: JSON.stringify(additionalData.user_properties || []),
                    user_preferences: JSON.stringify(additionalData.user_preferences || []),
                    profanity_status: 1
                };
                
                const newUserResult = await this.db.executeQuery(
                    sourceId, insertUserQuery, [
                        sourceId, defaultUserData.first_name, defaultUserData.last_name,
                        defaultUserData.user_name, deviceId, defaultUserData.device_version,
                        loginPlatformSource, currentTime, currentTime, currentTime,
                        partitionId, defaultUserData.opt_in,
                        defaultUserData.user_properties, defaultUserData.user_preferences,
                        defaultUserData.profanity_status
                    ]
                );
                
                const newUser = newUserResult.rows[0];
                const response = buildUserResponse({
                    device_id: deviceId,
                    user_guid: newUser.user_guid,
                    source_id: sourceId,
                    user_name: defaultUserData.user_name,
                    first_name: defaultUserData.first_name,
                    last_name: defaultUserData.last_name,
                    profanity_status: defaultUserData.profanity_status,
                    login_platform_source: loginPlatformSource,
                    user_properties: JSON.parse(defaultUserData.user_properties),
                    user_preferences: JSON.parse(defaultUserData.user_preferences)
                }, currentTime);
                
                const duration = Date.now() - startTime;
                logPerformance('userLogin', duration, true, { 
                    shardId: newUserResult.shardId, 
                    partitionId: newUserResult.partitionId 
                });
                
                return {
                    success: true,
                    data: response,
                    userId: newUser.user_id, // ✅ FIXED: Return actual user_id
                    shardId: newUserResult.shardId,
                    partitionId: newUserResult.partitionId
                };
            }
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
            const partitionId = this.calculatePartitionId(sourceId);
            
            // DIRECT SQL: Get user profile
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
            // Business logic validation in Node.js
            const formationValidation = validateFormation(teamData.inplayEntities);
            if (!formationValidation.valid) {
                return {
                    success: false,
                    error: `Invalid formation: ${formationValidation.issues.join(', ')}`
                };
            }
            
            const budgetValidation = validateBudget(teamData.inplayEntities);
            if (!budgetValidation.valid) {
                return {
                    success: false,
                    error: `Budget exceeded: ${budgetValidation.totalCost} > ${budgetValidation.budgetLimit}`
                };
            }
            
            // Prepare data for database
            const transferId = uuidv4();
            const teamPlayers = teamData.inplayEntities.map(e => e.entity_id);
            const teamJson = {
                inplay_entities: teamData.inplayEntities,
                reserved_entities: teamData.reservedEntities
            };
            
            // Get next team number using direct SQL
            const getTeamNoQuery = `
                SELECT COALESCE(MAX(team_no), 0) + 1 AS next_team_no
                FROM gameplay.user_teams
                WHERE user_id = $1 AND partition_id = $2 AND season_id = $3
            `;
            
            const teamNoResult = await this.db.executeQuery(
                userData.sourceId, getTeamNoQuery, 
                [userData.userId, userData.partitionId, CURRENT_SEASON]
            );
            
            const nextTeamNo = teamNoResult.rows[0]?.next_team_no || 1;
            
            // DIRECT SQL: Execute transaction with multiple operations
            const operations = [
                {
                    query: `INSERT INTO gameplay.user_teams (
                        user_id, team_no, team_name, upper_team_name, season_id,
                        gameset_id, gameday_id, partition_id
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                    params: [
                        userData.userId, nextTeamNo, teamData.teamName, teamData.teamName.toUpperCase(),
                        CURRENT_SEASON, gamesetId, gamedayId, userData.partitionId
                    ]
                },
                {
                    query: `INSERT INTO gameplay.user_team_detail (
                        season_id, user_id, team_no, gameset_id, gameday_id, from_gameset_id,
                        from_gameday_id, to_gameset_id, team_valuation, remaining_budget,
                        team_players, captain_player_id, vice_captain_player_id, team_json,
                        transfers_allowed, transfers_made, transfers_left, booster_id,
                        booster_player_id, partition_id, device_id
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)`,
                    params: [
                        CURRENT_SEASON, userData.userId, nextTeamNo, gamesetId, gamedayId,
                        gamesetId, gamedayId, -1, budgetValidation.totalCost, budgetValidation.remainingBudget,
                        teamPlayers, teamData.captainPlayerId, teamData.viceCaptainPlayerId,
                        JSON.stringify(teamJson), teamData.transfersAllowed, teamData.transfersMade,
                        teamData.transfersLeft(), teamData.boosterId, teamData.boosterPlayerId,
                        userData.partitionId, userData.deviceId
                    ]
                },
                {
                    query: `INSERT INTO gameplay.user_team_booster_transfer_detail (
                        season_id, transfer_id, user_id, team_no, gameset_id, gameday_id,
                        booster_id, original_team_players, players_out, players_in,
                        new_team_players, transfers_made, transfer_json, device_id, partition_id
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
                    params: [
                        CURRENT_SEASON, transferId, userData.userId, nextTeamNo,
                        gamesetId, gamedayId, teamData.boosterId, [], [], [],
                        teamPlayers, 0, JSON.stringify({ action: 'team_created', fantasy_type: fantasyType }),
                        userData.deviceId, userData.partitionId
                    ]
                }
            ];
            
            const result = await this.db.executeTransaction(userData.sourceId, operations);
            
            const duration = Date.now() - startTime;
            logPerformance('saveTeam', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
            });
            
            return {
                success: true,
                data: {
                    success: true,
                    team_no: nextTeamNo,
                    transfer_id: transferId,
                    message: 'Team created successfully'
                },
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

    async getUserTeams(userData, gamesetId) {
        const startTime = Date.now();
        try {
            // DIRECT SQL: Get user teams
            const query = `
                SELECT 
                    utd.team_no, ut.team_name, ut.profanity_status, utd.team_valuation,
                    utd.remaining_budget, utd.captain_player_id, utd.vice_captain_player_id,
                    utd.team_players, utd.transfers_allowed, utd.transfers_made, utd.transfers_left,
                    utd.booster_id, utd.booster_player_id, utd.team_json, utd.gameset_id, utd.gameday_id
                FROM gameplay.user_team_detail utd
                JOIN gameplay.user_teams ut ON ut.user_id = utd.user_id 
                    AND ut.team_no = utd.team_no 
                    AND ut.partition_id = utd.partition_id
                    AND ut.season_id = utd.season_id
                WHERE utd.user_id = $1 
                    AND utd.partition_id = $2 
                    AND utd.season_id = $3
                ORDER BY utd.team_no, utd.gameset_id DESC, utd.gameday_id DESC
            `;
            
            const result = await this.db.executeQuery(
                userData.sourceId, query, 
                [userData.userId, userData.partitionId, CURRENT_SEASON]
            );
            
            // Business logic processing in Node.js
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
                    points: "0",
                    rank: 0
                };
            });
            
            const duration = Date.now() - startTime;
            logPerformance('getUserTeams', duration, true, { 
                shardId: result.shardId, 
                partitionId: result.partitionId 
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

    async transferTeam(userData, teamNo, entitiesIn, entitiesOut, gamesetId, gamedayId, 
                      captainId, viceCaptainId, boosterId, boosterPlayerId, fantasyType = 1) {
        const startTime = Date.now();
        try {
            // Business logic validation in Node.js
            if (!entitiesIn.length || !entitiesOut.length) {
                return {
                    success: false,
                    error: 'Invalid transfer: entities_in and entities_out cannot be empty'
                };
            }
            
            if (entitiesIn.length !== entitiesOut.length) {
                return {
                    success: false,
                    error: 'Transfer count mismatch: entities_in and entities_out must have same count'
                };
            }
            
            // DIRECT SQL: Get current team state
            const getCurrentTeamQuery = `
                SELECT 
                    team_valuation, remaining_budget, team_players,
                    captain_player_id, vice_captain_player_id, team_json,
                    transfers_allowed, transfers_made, transfers_left,
                    booster_id, booster_player_id
                FROM gameplay.user_team_detail
                WHERE user_id = $1 AND partition_id = $2 AND season_id = $3
                    AND team_no = $4 AND gameset_id = $5 AND gameday_id = $6
            `;
            
            const currentTeamResult = await this.db.executeQuery(
                userData.sourceId, getCurrentTeamQuery,
                [userData.userId, userData.partitionId, CURRENT_SEASON, teamNo, gamesetId, gamedayId]
            );
            
            if (currentTeamResult.rows.length === 0) {
                return {
                    success: false,
                    error: `Team ${teamNo} not found for user ${userData.userId}`
                };
            }
            
            const currentTeam = currentTeamResult.rows[0];
            
            // Transfer limit validation (business logic in Node.js)
            const currentTransfersMade = currentTeam.transfers_made || 0;
            const transfersAllowed = currentTeam.transfers_allowed || 5;
            const freeTransfersLeft = Math.max(0, transfersAllowed - currentTransfersMade);
            
            if (entitiesOut.length > freeTransfersLeft) {
                return {
                    success: false,
                    error: `Transfer limit exceeded. You have ${freeTransfersLeft} free transfers left but trying to make ${entitiesOut.length} transfers.`
                };
            }
            
            // Calculate new team composition (business logic in Node.js)
            const currentInplay = Array.isArray(currentTeam.team_players) ? 
                currentTeam.team_players.map(id => ({ entity_id: id, skill_id: 1 })) : [];
            
            let newInplay = currentInplay.filter(entity =>
                !entitiesOut.some(outEntity => outEntity.entity_id === entity.entity_id)
            );
            
            entitiesIn.forEach(inEntity => {
                newInplay.push({
                    entity_id: inEntity.entity_id,
                    skill_id: inEntity.skill_id
                });
            });
            
            // Execute transfer using direct SQL operations
            const transferId = uuidv4();
            const newTransfersMade = currentTransfersMade + entitiesOut.length;
            const newTransfersLeft = Math.max(0, transfersAllowed - newTransfersMade);
            
            // Update team detail and log transfer
            const operations = [
                {
                    query: `UPDATE gameplay.user_team_detail 
                            SET team_players = $1, captain_player_id = $2, vice_captain_player_id = $3,
                                booster_id = $4, booster_player_id = $5, transfers_made = $6,
                                transfers_left = $7, updated_date = now()
                            WHERE user_id = $8 AND partition_id = $9 AND season_id = $10
                                AND team_no = $11 AND gameset_id = $12 AND gameday_id = $13`,
                    params: [
                        newInplay.map(e => e.entity_id), captainId, viceCaptainId,
                        boosterId, boosterPlayerId, newTransfersMade, newTransfersLeft,
                        userData.userId, userData.partitionId, CURRENT_SEASON,
                        teamNo, gamesetId, gamedayId
                    ]
                },
                {
                    query: `INSERT INTO gameplay.user_team_booster_transfer_detail (
                        season_id, transfer_id, user_id, team_no, gameset_id, gameday_id,
                        booster_id, original_team_players, players_out, players_in,
                        new_team_players, transfers_made, transfer_json, device_id, partition_id
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
                    params: [
                        CURRENT_SEASON, transferId, userData.userId, teamNo,
                        gamesetId, gamedayId, boosterId, currentTeam.team_players,
                        entitiesOut.map(e => e.entity_id), entitiesIn.map(e => e.entity_id),
                        newInplay.map(e => e.entity_id), newTransfersMade,
                        JSON.stringify({ action: 'transfer', fantasy_type: fantasyType }),
                        userData.deviceId, userData.partitionId
                    ]
                }
            ];
            
            await this.db.executeTransaction(userData.sourceId, operations);
            
            const transferResult = {
                success: true,
                transferId,
                newTransfersMade,
                newTransfersLeft,
                newTeamValuation: currentTeam.team_valuation,
                newRemainingBudget: currentTeam.remaining_budget
            };
            
            const duration = Date.now() - startTime;
            logPerformance('transferTeam', duration, true, { 
                shardId: currentTeamResult.shardId, 
                partitionId: currentTeamResult.partitionId 
            });
            
            return {
                success: true,
                data: transferResult,
                shardId: currentTeamResult.shardId,
                partitionId: currentTeamResult.partitionId
            };
        } catch (error) {
            const duration = Date.now() - startTime;
            logPerformance('transferTeam', duration, false, { error: error.message });
            console.error('Transfer team failed:', error.message);
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
    const batchSize = Math.min(50, Math.max(5, Math.floor(numUsers / 100)));

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
// ✅ FIXED PERFORMANCE TESTING - ALL 5 APIs WITH ROBUST ERROR HANDLING
// ====================================================================

async function runPerformanceTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} CockroachDB performance tests with ALL APIs...`.cyan);
    const concurrencyLevel = Math.min(15, Math.max(3, Math.floor(numTests / 1000)));
    const testPromises = [];

    for (let i = 0; i < numTests; i++) {
        const testPromise = async () => {
            const userData = usersData[Math.floor(Math.random() * usersData.length)];
            try {
                // --- ROBUST TEST SEQUENCE FOR ALL 5 APIs ---

                // 1. USER LOGIN ✅
                const loginResult = await api.userLogin(userData.sourceId, userData.deviceId, userData.loginPlatformSource);
                if (!loginResult || !loginResult.success) {
                    return; // Exit early if login fails
                }

                // Extract the actual user ID from login result
                const actualUserId = loginResult.userId || userData.userId;

                // 2. GET USER PROFILE ✅
                const profileResult = await api.getUserProfile(userData.sourceId, actualUserId);
                if (!profileResult || !profileResult.success) {
                    return; // Exit early if profile fetch fails
                }

                // 3. SAVE TEAM ✅
                const teamData = generateTeamData(userData, 1); // Use team_no 1 for simplicity
                const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);
                if (!saveResult || !saveResult.success) {
                    return; // Exit early if save team fails
                }

                // 4. GET USER TEAMS ✅
                const teamsResult = await api.getUserTeams(userData, CURRENT_GAMESET);
                if (!teamsResult || !teamsResult.success) {
                    return; // Exit early if get teams fails
                }

                // 5. TRANSFER TEAM ✅ (10% frequency, same as Cassandra POC)
                if (Math.random() < 0.1) { 
                    const entitiesIn = [{ entity_id: 1015, skill_id: 4, order: 1 }]; // Haaland
                    const entitiesOut = [{ entity_id: 1003, skill_id: 4, order: 1 }]; // Kane
                    await api.transferTeam(
                        userData,
                        teamData.teamNo,
                        entitiesIn,
                        entitiesOut,
                        CURRENT_GAMESET,
                        CURRENT_GAMEDAY,
                        teamData.captainPlayerId,
                        teamData.viceCaptainPlayerId,
                        teamData.boosterId,
                        teamData.boosterPlayerId
                    );
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

    console.log('✅ CockroachDB performance tests completed with ALL APIs'.green);
}

// ====================================================================
// PERFORMANCE REPORTING
// ====================================================================

function generatePerformanceReport(cockroachConn) {
    const report = {
        timestamp: new Date().toISOString(),
        database: 'CockroachDB (Complete Fixed)',
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
    console.log('FANTASY GAME COCKROACHDB POC - COMPLETE FIXED PERFORMANCE REPORT'.bold.yellow);
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

    console.log('🎮 Starting Fantasy Game CockroachDB POC (Complete Fixed - All 5 APIs)'.bold.cyan);
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
        console.log('⏱️ Starting CockroachDB performance tests with ALL APIs...'.cyan);
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

        console.log('🎉 CockroachDB POC testing completed successfully with ALL APIs'.bold.green);
        console.log('✨ All business logic handled in Node.js layer for better maintainability'.bold.green);
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
