#!/usr/bin/env node

/**
 * Fantasy Game Cassandra POC Testing Script - Complete Optimized Version
 * ====================================================================
 *
 * This script includes all optimizations and fixes:
 * - Fixed BatchStatement compatibility issues
 * - Enhanced formation validation for transfers
 * - High-load connection optimizations with circuit breaker
 * - Complete API implementation with all requested features
 *
 * Usage:
 * node fantasy-game-poc.js --users 1000 --tests 100
 * node fantasy-game-poc.js --users 20000 --tests 100000 --skip-data --high-load
 */

const cassandra = require('cassandra-driver');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const path = require('path');
const { program } = require('commander');
const colors = require('colors');

// ====================================================================
// CONFIGURATION & OPTIMIZED SETUP
// ====================================================================

const OPTIMIZED_CASSANDRA_CONFIG = {
    contactPoints: ['127.0.0.1:9042', '127.0.0.1:9043', '127.0.0.1:9044'],
    localDataCenter: 'datacenter1',
    keyspace: 'fantasy_game',
    pooling: {
        coreConnectionsPerHost: {
            [cassandra.types.distance.local]: 2,
            [cassandra.types.distance.remote]: 1
        },
        maxConnectionsPerHost: {
            [cassandra.types.distance.local]: 8,
            [cassandra.types.distance.remote]: 2
        },
        maxRequestsPerConnection: 32000,
        heartBeatInterval: 30000
    },
    socketOptions: {
        readTimeout: 15000,
        connectTimeout: 8000,
        keepAlive: true,
        keepAliveDelay: 0
    },
    queryOptions: {
        consistency: cassandra.types.consistencies.localOne,
        prepare: true,
        autoPage: false
    }
};

const HIGH_LOAD_CASSANDRA_CONFIG = {
    contactPoints: ['127.0.0.1:9042', '127.0.0.1:9043', '127.0.0.1:9044'],
    localDataCenter: 'datacenter1',
    keyspace: 'fantasy_game',
    pooling: {
        coreConnectionsPerHost: {
            [cassandra.types.distance.local]: 4,
            [cassandra.types.distance.remote]: 2
        },
        maxConnectionsPerHost: {
            [cassandra.types.distance.local]: 16,
            [cassandra.types.distance.remote]: 4
        },
        maxRequestsPerConnection: 16384,
        heartBeatInterval: 60000
    },
    socketOptions: {
        readTimeout: 30000,
        connectTimeout: 15000,
        keepAlive: true,
        keepAliveDelay: 1000,
        tcpNoDelay: true
    },
    queryOptions: {
        consistency: cassandra.types.consistencies.localOne,
        prepare: true,
        autoPage: false,
        fetchSize: 100
    },
    policies: {
        retry: new cassandra.policies.retry.IdempotenceAwareRetryPolicy(new cassandra.policies.retry.RetryPolicy()),
        reconnection: new cassandra.policies.reconnection.ExponentialReconnectionPolicy(1000, 10000)
    }
};

const DEFAULT_USERS = 1000;
const DEFAULT_TESTS = 100;
const CURRENT_SEASON = 2024;
const CURRENT_GAMESET = 15;
const CURRENT_GAMEDAY = 3;

// ====================================================================
// ENHANCED PERFORMANCE METRICS
// ====================================================================

class PerformanceMonitor {
    constructor() {
        this.metrics = new Map();
        this.startTime = Date.now();
        this.operationStats = {
            userLogin: [],
            getUserProfile: [],
            saveTeam: [],
            getUserTeams: [],
            transferTeam: [],
            transferValidationErrors: [],
            errors: []
        };
    }
    
    startOperation(operationName, identifier = '') {
        const key = `${operationName}_${identifier}_${Date.now()}`;
        this.metrics.set(key, {
            operation: operationName,
            identifier,
            startTime: process.hrtime.bigint(),
            memoryBefore: process.memoryUsage()
        });
        return key;
    }
    
    endOperation(key) {
        const metric = this.metrics.get(key);
        if (!metric) return;
        
        const duration = Number(process.hrtime.bigint() - metric.startTime) / 1000000;
        const memoryAfter = process.memoryUsage();
        
        const result = {
            operation: metric.operation,
            duration,
            memoryDelta: {
                heapUsed: memoryAfter.heapUsed - metric.memoryBefore.heapUsed,
                heapTotal: memoryAfter.heapTotal - metric.memoryBefore.heapTotal
            }
        };
        
        this.metrics.delete(key);
        this.logMetric(result);
        
        return result;
    }
    
    logMetric(result) {
        if (!this.operationStats[result.operation]) {
            this.operationStats[result.operation] = [];
        }
        this.operationStats[result.operation].push(result.duration);
    }
    
    getMemoryStats() {
        return {
            uptime: Date.now() - this.startTime,
            memory: process.memoryUsage(),
            activeMetrics: this.metrics.size
        };
    }
    
    getStats() {
        return this.operationStats;
    }
}

const perfMonitor = new PerformanceMonitor();

// ====================================================================
// ENHANCED FANTASY FOOTBALL DATA WITH PROPER FORMATION SUPPORT
// ====================================================================

const FOOTBALL_PLAYERS = [
    // Goalkeepers (skillId: 5)
    { id: 1011, name: "Alisson Becker", skillId: 5, price: 5.5, value: 5.5, team: "Liverpool" },
    { id: 1016, name: "Thibaut Courtois", skillId: 5, price: 5.0, value: 5.0, team: "Real Madrid" },
    { id: 1021, name: "Gianluigi Donnarumma", skillId: 5, price: 4.5, value: 4.5, team: "PSG" },
    { id: 1022, name: "Ederson", skillId: 5, price: 5.0, value: 5.0, team: "Man City" },
    { id: 1031, name: "Marc-André ter Stegen", skillId: 5, price: 4.8, value: 4.8, team: "Barcelona" },
    
    // Defenders (skillId: 1)
    { id: 1004, name: "Virgil van Dijk", skillId: 1, price: 6.5, value: 6.5, team: "Liverpool" },
    { id: 1007, name: "Sergio Ramos", skillId: 1, price: 5.0, value: 5.0, team: "PSG" },
    { id: 1020, name: "João Cancelo", skillId: 1, price: 7.0, value: 7.0, team: "Man City" },
    { id: 1023, name: "Marquinhos", skillId: 1, price: 5.5, value: 5.5, team: "PSG" },
    { id: 1024, name: "Ruben Dias", skillId: 1, price: 6.0, value: 6.0, team: "Man City" },
    { id: 1025, name: "Andrew Robertson", skillId: 1, price: 6.5, value: 6.5, team: "Liverpool" },
    { id: 1026, name: "Trent Alexander-Arnold", skillId: 1, price: 7.5, value: 7.5, team: "Liverpool" },
    { id: 1032, name: "Achraf Hakimi", skillId: 1, price: 6.8, value: 6.8, team: "PSG" },
    { id: 1033, name: "Kyle Walker", skillId: 1, price: 6.2, value: 6.2, team: "Man City" },
    
    // Midfielders (skillId: 2)
    { id: 1001, name: "Kevin De Bruyne", skillId: 2, price: 12.5, value: 12.5, team: "Man City" },
    { id: 1006, name: "N'Golo Kanté", skillId: 2, price: 5.5, value: 5.5, team: "Al-Ittihad" },
    { id: 1008, name: "Luka Modrić", skillId: 2, price: 8.5, value: 8.5, team: "Real Madrid" },
    { id: 1012, name: "Mason Mount", skillId: 2, price: 6.5, value: 6.5, team: "Man United" },
    { id: 1014, name: "Bruno Fernandes", skillId: 2, price: 8.5, value: 8.5, team: "Man United" },
    { id: 1018, name: "Pedri", skillId: 2, price: 6.0, value: 6.0, team: "Barcelona" },
    { id: 1027, name: "Casemiro", skillId: 2, price: 7.0, value: 7.0, team: "Man United" },
    { id: 1034, name: "Jude Bellingham", skillId: 2, price: 9.0, value: 9.0, team: "Real Madrid" },
    
    // Forwards (skillId: 3)
    { id: 1002, name: "Mohamed Salah", skillId: 3, price: 13.0, value: 13.0, team: "Liverpool" },
    { id: 1005, name: "Sadio Mané", skillId: 3, price: 10.0, value: 10.0, team: "Al Nassr" },
    { id: 1010, name: "Kylian Mbappé", skillId: 3, price: 12.0, value: 12.0, team: "PSG" },
    { id: 1013, name: "Phil Foden", skillId: 3, price: 8.0, value: 8.0, team: "Man City" },
    { id: 1019, name: "Vinicius Jr.", skillId: 3, price: 9.5, value: 9.5, team: "Real Madrid" },
    { id: 1028, name: "Raheem Sterling", skillId: 3, price: 9.0, value: 9.0, team: "Chelsea" },
    { id: 1035, name: "Bukayo Saka", skillId: 3, price: 8.5, value: 8.5, team: "Arsenal" },
    
    // Strikers (skillId: 4)
    { id: 1003, name: "Harry Kane", skillId: 4, price: 11.5, value: 11.5, team: "Bayern Munich" },
    { id: 1009, name: "Robert Lewandowski", skillId: 4, price: 9.0, value: 9.0, team: "Barcelona" },
    { id: 1015, name: "Erling Haaland", skillId: 4, price: 15.0, value: 15.0, team: "Man City" },
    { id: 1017, name: "Karim Benzema", skillId: 4, price: 10.0, value: 10.0, team: "Al-Ittihad" },
    { id: 1029, name: "Darwin Nunez", skillId: 4, price: 8.5, value: 8.5, team: "Liverpool" },
    { id: 1030, name: "Victor Osimhen", skillId: 4, price: 9.5, value: 9.5, team: "Napoli" },
    { id: 1036, name: "Olivier Giroud", skillId: 4, price: 7.5, value: 7.5, team: "Milan" }
];

// Skill ID mapping for formation validation
const SKILL_POSITIONS = {
    1: 'DEFENDER',
    2: 'MIDFIELDER',
    3: 'FORWARD',
    4: 'STRIKER',
    5: 'GOALKEEPER'
};

// Required formation constraints
const FORMATION_RULES = {
    1: { min: 3, max: 5 },
    2: { min: 3, max: 5 },
    3: { min: 1, max: 3 },
    4: { min: 1, max: 3 },
    5: { min: 1, max: 1 }
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
// OPTIMIZED PLAYER POOL WITH OBJECT POOLING
// ====================================================================

class PlayerPool {
    constructor() {
        this.playersBySkill = this.groupPlayersBySkill();
        this.usedPlayers = new Set();
    }
    
    groupPlayersBySkill() {
        const grouped = {};
        FOOTBALL_PLAYERS.forEach(player => {
            if (!grouped[player.skillId]) {
                grouped[player.skillId] = [];
            }
            grouped[player.skillId].push(player);
        });
        return grouped;
    }
    
    getValidTeam(constraints = { defenders: 4, midfielders: 4, forwards: 1, striker: 1 }) {
        this.reset();
        
        const team = {
            goalkeepers: this.getPlayersBySkill(5, 1),
            defenders: this.getPlayersBySkill(1, constraints.defenders),
            midfielders: this.getPlayersBySkill(2, constraints.midfielders),
            forwards: this.getPlayersBySkill(3, constraints.forwards),
            strikers: this.getPlayersBySkill(4, constraints.striker)
        };
        
        const mainTeam = [...team.goalkeepers, ...team.defenders, ...team.midfielders, ...team.forwards, ...team.strikers];
        const reserveTeam = this.getReservePlayers(4);
        
        return {
            mainTeam,
            reserveTeam,
            totalCost: [...mainTeam, ...reserveTeam].reduce((sum, player) => sum + player.price, 0)
        };
    }
    
    getPlayersBySkill(skillId, count) {
        const available = this.playersBySkill[skillId]?.filter(p => !this.usedPlayers.has(p.id)) || [];
        const selected = available.slice(0, count);
        selected.forEach(player => this.usedPlayers.add(player.id));
        return selected;
    }
    
    getReservePlayers(count) {
        const available = FOOTBALL_PLAYERS.filter(p => !this.usedPlayers.has(p.id));
        return available.slice(0, count);
    }
    
    reset() {
        this.usedPlayers.clear();
    }
}

const playerPool = new PlayerPool();

// ====================================================================
// ENHANCED CONCURRENCY CONTROLLER WITH CIRCUIT BREAKER
// ====================================================================

class EnhancedConcurrencyController {
    constructor(maxConcurrency = 15, queueLimit = 2000, circuitBreakerThreshold = 50) {
        this.maxConcurrency = maxConcurrency;
        this.queueLimit = queueLimit;
        this.running = 0;
        this.queue = [];
        this.completed = 0;
        this.errors = 0;
        this.circuitBreakerThreshold = circuitBreakerThreshold;
        this.circuitOpen = false;
        this.lastErrorTime = 0;
        this.circuitResetTimeout = 30000;
    }
    
    async execute(taskFn) {
        if (this.circuitOpen) {
            if (Date.now() - this.lastErrorTime > this.circuitResetTimeout) {
                this.circuitOpen = false;
                this.errors = 0;
                console.log('🔄 Circuit breaker reset - resuming operations'.green);
            } else {
                throw new Error('Circuit breaker is open - too many errors');
            }
        }
        
        return new Promise((resolve, reject) => {
            if (this.queue.length >= this.queueLimit) {
                reject(new Error('Queue limit exceeded'));
                return;
            }
            
            this.queue.push({ taskFn, resolve, reject });
            this.processQueue();
        });
    }
    
    async processQueue() {
        if (this.running >= this.maxConcurrency || this.queue.length === 0) {
            return;
        }
        
        this.running++;
        const { taskFn, resolve, reject } = this.queue.shift();
        
        try {
            const result = await taskFn();
            resolve(result);
            this.completed++;
        } catch (error) {
            this.errors++;
            this.lastErrorTime = Date.now();
            
            if (this.errors >= this.circuitBreakerThreshold) {
                this.circuitOpen = true;
                console.log('⚡ Circuit breaker opened - too many errors'.red);
            }
            
            reject(error);
        } finally {
            this.running--;
            setImmediate(() => this.processQueue());
        }
    }
    
    getStats() {
        return {
            running: this.running,
            queued: this.queue.length,
            completed: this.completed,
            errors: this.errors,
            circuitOpen: this.circuitOpen
        };
    }
}

// ====================================================================
// ENHANCED CASSANDRA CONNECTION WITH HEALTH MONITORING
// ====================================================================

class CassandraConnection {
    constructor(highLoad = false) {
        this.client = null;
        this.preparedStatements = new Map();
        this.config = highLoad ? HIGH_LOAD_CASSANDRA_CONFIG : OPTIMIZED_CASSANDRA_CONFIG;
        this.highLoad = highLoad;
        this.healthCheckInterval = null;
        this.isHealthy = true;
    }

    async connect() {
        try {
            this.client = new cassandra.Client(this.config);
            await this.client.connect();
            
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

            const mode = this.highLoad ? 'high-load' : 'optimized';
            console.log(`✅ Connected to Cassandra cluster with ${mode} settings`.green);
            await this.prepareCQLStatements();
            
            if (this.highLoad) {
                this.startHealthCheck();
            }
            
            return true;
        } catch (error) {
            console.error('❌ Failed to connect to Cassandra:'.red, error.message);
            return false;
        }
    }

    startHealthCheck() {
        this.healthCheckInterval = setInterval(async () => {
            try {
                await this.client.execute('SELECT now() FROM system.local');
                if (!this.isHealthy) {
                    this.isHealthy = true;
                    console.log('✅ Cassandra connection restored'.green);
                }
            } catch (error) {
                if (this.isHealthy) {
                    this.isHealthy = false;
                    console.error('❌ Cassandra health check failed:'.red, error.message);
                }
            }
        }, 10000);
    }

    async executeBatch(statements) {
        if (this.highLoad && !this.isHealthy) {
            throw new Error('Cassandra connection is unhealthy');
        }
        
        try {
            const queries = statements.map(stmt => ({
                query: stmt.query,
                params: stmt.params
            }));
            
            const options = {
                prepare: true,
                consistency: cassandra.types.consistencies.localOne
            };
            
            if (this.highLoad) {
                options.retry = true;
            }
            
            return await this.client.batch(queries, options);
        } catch (error) {
            console.error('Batch execution failed:', error.message);
            if (error.message.includes('Socket was closed')) {
                this.isHealthy = false;
            }
            throw error;
        }
    }

    async prepareCQLStatements() {
        const statements = {
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
        if (this.healthCheckInterval) {
            clearInterval(this.healthCheckInterval);
        }
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
    const platform = SOURCE_PLATFORMS[userId % SOURCE_PLATFORMS.length];
    const sourceId = `${platform.prefix}${userId.toString().padStart(9, '0')}`;
    
    return {
        userId,
        sourceId,
        userGuid: uuidv4(),
        firstName: FIRST_NAMES[userId % FIRST_NAMES.length],
        lastName: LAST_NAMES[userId % LAST_NAMES.length],
        userName: `player_${userId}`,
        deviceId: (userId % 4) + 1,
        deviceVersion: ['1.0', '1.1', '1.2', '2.0'][userId % 4],
        loginPlatformSource: platform.id,
        partitionId: calculatePartitionId(sourceId),
        userBucket: calculateUserBucket(userId)
    };
}

function generateTeamDataOptimized(userData, teamNo) {
    const teamData = playerPool.getValidTeam();
    
    const inplayEntities = JSON.stringify(
        teamData.mainTeam.map((player, idx) => ({
            entityId: player.id,
            skillId: player.skillId,
            order: idx + 1
        }))
    );
    
    const reservedEntities = JSON.stringify(
        teamData.reserveTeam.map((player, idx) => ({
            entityId: player.id,
            skillId: player.skillId,
            order: idx + 1
        }))
    );
    
    const totalValuation = Math.round(teamData.totalCost * 100) / 100;
    
    return {
        teamNo,
        teamName: TEAM_NAMES[teamNo % TEAM_NAMES.length],
        teamValuation: totalValuation,
        remainingBudget: Math.round((100.0 - totalValuation) * 100) / 100,
        captainPlayerId: teamData.mainTeam[0].id,
        viceCaptainPlayerId: teamData.mainTeam[1].id,
        inplayEntities,
        reservedEntities,
        boosterId: (teamNo % 3) + 1,
        boosterPlayerId: teamData.mainTeam[teamNo % teamData.mainTeam.length].id,
        transfersAllowed: 5,
        transfersMade: teamNo % 4,
        transfersLeft: function () { return this.transfersAllowed - this.transfersMade; }
    };
}

// ====================================================================
// FIXED FORMATION VALIDATION FUNCTIONS
// ====================================================================

const validationCache = new Map();

function validateFormationCached(inplayEntities) {
    const cacheKey = JSON.stringify(inplayEntities.map(e => ({ skillId: e.skillId })));
    
    if (validationCache.has(cacheKey)) {
        return validationCache.get(cacheKey);
    }
    
    const result = validateFormation(inplayEntities);
    validationCache.set(cacheKey, result);
    
    if (validationCache.size > 1000) {
        const firstKey = validationCache.keys().next().value;
        validationCache.delete(firstKey);
    }
    
    return result;
}

function validateFormation(inplayEntities) {
    const skillCounts = {};
    const issues = [];
    
    inplayEntities.forEach(entity => {
        skillCounts[entity.skillId] = (skillCounts[entity.skillId] || 0) + 1;
    });

    const totalPlayers = inplayEntities.length;
    if (totalPlayers !== 11) {
        issues.push(`Team must have exactly 11 players, found ${totalPlayers}`);
    }

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

// FIXED: Generate valid transfer data that maintains exactly 11 players
function generateValidTransferData(currentTeam) {
    const inplayEntities = JSON.parse(currentTeam.inplay_entities || '[]');
    
    if (inplayEntities.length === 0) {
        return { entitiesIn: [], entitiesOut: [] };
    }
    
    if (inplayEntities.length !== 11) {
        console.warn(`❌ Current team has ${inplayEntities.length} players, expected 11. Skipping transfer.`);
        return { entitiesIn: [], entitiesOut: [] };
    }
    
    // Get a random non-goalkeeper player to transfer out
    const nonGoalkeepers = inplayEntities.filter(p => p.skillId !== 5);
    if (nonGoalkeepers.length === 0) {
        return { entitiesIn: [], entitiesOut: [] };
    }
    
    const playerOut = nonGoalkeepers[Math.floor(Math.random() * nonGoalkeepers.length)];
    
    // Find a valid replacement with same position
    const availableReplacements = FOOTBALL_PLAYERS.filter(p => 
        p.skillId === playerOut.skillId && 
        p.id !== playerOut.entityId &&
        !inplayEntities.some(existing => existing.entityId === p.id)
    );
    
    if (availableReplacements.length === 0) {
        return { entitiesIn: [], entitiesOut: [] };
    }
    
    const playerIn = availableReplacements[Math.floor(Math.random() * availableReplacements.length)];
    
    // CRITICAL: Ensure 1:1 replacement - exactly one player in, one player out
    return {
        entitiesIn: [{
            entity_id: playerIn.id,
            skill_id: playerIn.skillId,
            order: playerOut.order
        }],
        entitiesOut: [{
            entity_id: playerOut.entityId,
            skill_id: playerOut.skillId,
            order: playerOut.order
        }]
    };
}

function logPerformance(operation, duration, success = true) {
    const stats = perfMonitor.getStats();
    if (success) {
        stats[operation].push(duration);
    } else {
        stats.errors.push({
            operation,
            duration,
            timestamp: new Date().toISOString()
        });
    }
}

// ====================================================================
// COMPLETE API IMPLEMENTATION
// ====================================================================

class FantasyGameAPI {
    constructor(cassandraConn) {
        this.db = cassandraConn;
    }

    async userLogin(sourceId, deviceId, loginPlatformSource, userData = null) {
        const operationKey = perfMonitor.startOperation('userLogin');
        const partitionId = calculatePartitionId(sourceId);
        
        try {
            const getUserStmt = this.db.preparedStatements.get('getUserBySource');
            const result = await this.db.client.execute(getUserStmt, [
                partitionId, sourceId
            ]);

            if (result.rows.length > 0) {
                const userRow = result.rows[0];
                const profile = await this.getUserProfile(userRow.user_id, partitionId);
                
                perfMonitor.endOperation(operationKey);
                
                return {
                    success: true,
                    user_id: userRow.user_id,
                    user_guid: userRow.user_guid.toString(),
                    profile: profile
                };
            } else {
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

                const userStmt = this.db.preparedStatements.get('insertUser');
                const lookupStmt = this.db.preparedStatements.get('insertUserBySource');
                
                const statements = [
                    {
                        query: userStmt,
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
                        query: lookupStmt,
                        params: [
                            userData.partitionId, userData.sourceId, userData.userId,
                            cassandra.types.Uuid.fromString(userData.userGuid), 
                            userData.loginPlatformSource, now
                        ]
                    }
                ];

                await this.db.executeBatch(statements);

                perfMonitor.endOperation(operationKey);

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
            perfMonitor.endOperation(operationKey);
            logPerformance('userLogin', 0, false);
            console.error('User login failed:', error);
            return { success: false, error: error.message };
        }
    }

    async getUserProfile(userId, partitionId) {
        const operationKey = perfMonitor.startOperation('getUserProfile');
        
        try {
            const stmt = this.db.preparedStatements.get('getUserProfile');
            const result = await this.db.client.execute(stmt, [partitionId, userId]);
            
            if (result.rows.length === 0) {
                perfMonitor.endOperation(operationKey);
                return null;
            }

            const row = result.rows[0];
            perfMonitor.endOperation(operationKey);

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
            perfMonitor.endOperation(operationKey);
            logPerformance('getUserProfile', 0, false);
            console.error(`Get user profile failed for user ${userId}:`, error.message);
            return null;
        }
    }

    async saveTeam(userData, teamData, gamesetId, gamedayId, fantasyType = 1) {
        const operationKey = perfMonitor.startOperation('saveTeam');
        const now = new Date();
        const transferId = uuidv4();

        const insertTeamLatestStmt = this.db.preparedStatements.get('insertTeamLatest');
        const insertTeamDetailsStmt = this.db.preparedStatements.get('insertTeamDetails');
        const insertTransferStmt = this.db.preparedStatements.get('insertTransfer');

        try {
            await this.db.client.execute(insertTeamLatestStmt, [
                userData.partitionId, userData.userBucket, userData.userId,
                teamData.teamNo, gamesetId, gamedayId,
                teamData.teamName, teamData.teamName.toUpperCase(),
                1,
                teamData.teamValuation, teamData.remainingBudget,
                teamData.captainPlayerId, teamData.viceCaptainPlayerId,
                teamData.inplayEntities, teamData.reservedEntities,
                teamData.boosterId, teamData.boosterPlayerId,
                teamData.transfersAllowed, teamData.transfersMade, teamData.transfersLeft(),
                0, 0,
                userData.deviceId, now, now
            ]);

            const toGamesetId = -1;
            await this.db.client.execute(insertTeamDetailsStmt, [
                userData.partitionId, userData.userBucket, gamesetId,
                userData.userId, teamData.teamNo, gamedayId,
                gamesetId, gamedayId,
                toGamesetId, null,
                teamData.teamValuation, teamData.remainingBudget,
                teamData.inplayEntities, teamData.reservedEntities,
                now, now
            ]);

            await this.db.client.execute(insertTransferStmt, [
                userData.partitionId, userData.userBucket, userData.userId, CURRENT_SEASON,
                teamData.teamNo, transferId,
                gamesetId, gamedayId, 'CREATE',
                teamData.boosterId, teamData.boosterPlayerId,
                '[]', '[]',
                '[]', teamData.inplayEntities,
                0, 0.0,
                JSON.stringify({ action: 'team_created', fantasy_type: fantasyType }),
                userData.deviceId, now, now
            ]);

            perfMonitor.endOperation(operationKey);
            return { success: true, transferId };
        } catch (error) {
            perfMonitor.endOperation(operationKey);
            logPerformance('saveTeam', 0, false);
            console.error('Save team failed:', error);
            return { success: false, error: error.message };
        }
    }

    async transferTeamOptimized(userData, teamNo, entitiesIn, entitiesOut, 
                              currentGamesetId, currentGamedayId, captainId, viceCaptainId, 
                              boosterId = null, boosterPlayerId = null, fantasyType = 1) {
        const operationKey = perfMonitor.startOperation('transferTeam');
        
        if (!entitiesIn.length || !entitiesOut.length) {
            perfMonitor.endOperation(operationKey);
            return {
                success: false,
                error: 'Invalid transfer: entities_in and entities_out cannot be empty',
                errorCode: 'INVALID_INPUT'
            };
        }
        
        if (entitiesIn.length !== entitiesOut.length) {
            perfMonitor.endOperation(operationKey);
            return {
                success: false,
                error: 'Transfer count mismatch: entities_in and entities_out must have same count',
                errorCode: 'TRANSFER_COUNT_MISMATCH'
            };
        }
        
        const now = new Date();
        const transferId = uuidv4();

        try {
            const currentTeam = await this.getCurrentTeamState(userData, teamNo);
            if (!currentTeam) {
                perfMonitor.endOperation(operationKey);
                return { 
                    success: false, 
                    error: `Team ${teamNo} not found for user ${userData.userId}`,
                    errorCode: 'TEAM_NOT_FOUND'
                };
            }

            const currentTransfersMade = currentTeam.transfers_made || 0;
            const transfersAllowed = currentTeam.transfers_allowed || 5;
            const freeTransfersLeft = Math.max(0, transfersAllowed - currentTransfersMade);
            
            if (entitiesOut.length > freeTransfersLeft && entitiesOut.length > 0) {
                perfMonitor.endOperation(operationKey);
                return {
                    success: false,
                    error: `Transfer limit exceeded. You have ${freeTransfersLeft} free transfers left but trying to make ${entitiesOut.length} transfers.`,
                    errorCode: 'TRANSFER_LIMIT_EXCEEDED',
                    transfersLeft: freeTransfersLeft,
                    transfersRequested: entitiesOut.length
                };
            }

            const currentInplay = JSON.parse(currentTeam.inplay_entities || '[]');
            const currentReserved = JSON.parse(currentTeam.reserved_entities || '[]');
            const ownedPlayerIds = [...currentInplay, ...currentReserved].map(p => p.entityId);

            const invalidTransferOut = entitiesOut.filter(entity => 
                !ownedPlayerIds.includes(entity.entity_id)
            );

            if (invalidTransferOut.length > 0) {
                perfMonitor.endOperation(operationKey);
                return {
                    success: false,
                    error: `Cannot transfer players you don't own: ${invalidTransferOut.map(e => e.entity_id).join(', ')}`,
                    errorCode: 'INVALID_PLAYER_OWNERSHIP',
                    invalidPlayers: invalidTransferOut.map(e => e.entity_id)
                };
            }

            // FIXED: Ensure proper team composition
            let newInplay = currentInplay.filter(entity => 
                !entitiesOut.some(outEntity => outEntity.entity_id === entity.entityId)
            );
            
            entitiesIn.forEach(inEntity => {
                newInplay.push({
                    entityId: inEntity.entity_id,
                    skillId: inEntity.skill_id,
                    order: inEntity.order
                });
            });

            const formationValidation = validateFormationCached(newInplay);
            if (!formationValidation.valid) {
                perfMonitor.endOperation(operationKey);
                const stats = perfMonitor.getStats();
                stats.transferValidationErrors.push({
                    errorCode: 'INVALID_FORMATION',
                    error: formationValidation.error
                });
                return {
                    success: false,
                    error: formationValidation.error,
                    errorCode: 'INVALID_FORMATION',
                    formationIssues: formationValidation.issues
                };
            }

            const budgetValidation = validateBudget(newInplay, currentTeam.remaining_budget || 15.0);
            if (!budgetValidation.valid) {
                perfMonitor.endOperation(operationKey);
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

            const newInplayEntities = JSON.stringify(newInplay);
            const newReservedEntities = currentTeam.reserved_entities;
            const newTeamValuation = budgetValidation.newValuation;
            const newRemainingBudget = budgetValidation.newRemainingBudget;
            const newTransfersMade = currentTransfersMade + entitiesOut.length;
            const newTransfersLeft = Math.max(0, transfersAllowed - newTransfersMade);

            const updateTeamLatestStmt = this.db.preparedStatements.get('updateTeamLatest');
            const insertTeamDetailsStmt = this.db.preparedStatements.get('insertTeamDetails');
            const updateTeamDetailsStmt = this.db.preparedStatements.get('updateTeamDetailsStatus');
            const insertTransferStmt = this.db.preparedStatements.get('insertTransfer');

            if (sameGameset) {
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
                if (updateTeamDetailsStmt) {
                    await this.db.client.execute(updateTeamDetailsStmt, [
                        currentGamesetId - 1, currentGamedayId - 1, now,
                        userData.partitionId, userData.userBucket, fromGamesetId,
                        userData.userId, teamNo, currentTeam.current_gameday_id
                    ]);
                }

                await this.db.client.execute(insertTeamDetailsStmt, [
                    userData.partitionId, userData.userBucket, currentGamesetId,
                    userData.userId, teamNo, currentGamedayId,
                    currentGamesetId, currentGamedayId,
                    -1, null,
                    newTeamValuation, newRemainingBudget,
                    newInplayEntities, newReservedEntities,
                    now, now
                ]);

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

            await this.db.client.execute(insertTransferStmt, [
                userData.partitionId, userData.userBucket, userData.userId, CURRENT_SEASON,
                teamNo, transferId,
                currentGamesetId, currentGamedayId, 'TRANSFER',
                boosterId || currentTeam.booster_id || 1,
                boosterPlayerId || currentTeam.booster_player_id || newInplay[0]?.entityId,
                JSON.stringify(entitiesIn), JSON.stringify(entitiesOut),
                currentTeam.inplay_entities, newInplayEntities,
                newTransfersMade, 0.0,
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

            perfMonitor.endOperation(operationKey);

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
            perfMonitor.endOperation(operationKey);
            logPerformance('transferTeam', 0, false);
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
        const operationKey = perfMonitor.startOperation('getUserTeams');
        try {
            const stmt = this.db.preparedStatements.get('getUserTeams');
            const result = await this.db.client.execute(stmt, [
                userData.partitionId, userData.userBucket, userData.userId
            ]);

            const teams = result.rows.map(row => {
                const inplayEntities = JSON.parse(row.inplay_entities || '[]');
                const reservedEntities = JSON.parse(row.reserved_entities || '[]');
                
                const formation = [
                    { skillId: 1, playerCount: 4 },
                    { skillId: 2, playerCount: 4 },
                    { skillId: 3, playerCount: 2 },
                    { skillId: 4, playerCount: 1 }
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

            perfMonitor.endOperation(operationKey);

            return {
                teamCreatedCount: teams.length,
                maxTeamAllowed: 5,
                rank: teams.length > 0 ? teams[0].rank : 0,
                totalPoints: String(teams.reduce((sum, team) => sum + parseFloat(team.points || 0), 0)),
                teams
            };
        } catch (error) {
            perfMonitor.endOperation(operationKey);
            logPerformance('getUserTeams', 0, false);
            console.error(`Get teams failed for user ${userData.userId}:`, error.message);
            return null;
        }
    }
}

// ====================================================================
// BATCH OPERATIONS FOR USER CREATION - FIXED
// ====================================================================

async function populateTestDataOptimized(api, numUsers) {
    console.log(`🔄 Generating test data for ${numUsers} users with batch operations...`.cyan);
    const usersData = [];
    const batchSize = 50;
    
    for (let i = 0; i < numUsers; i += batchSize) {
        const endIndex = Math.min(i + batchSize, numUsers);
        const batchPromises = [];
        
        for (let userId = i + 1; userId <= endIndex; userId++) {
            const userData = generateUserData(userId);
            usersData.push(userData);
            
            const now = new Date();
            const userProperties = JSON.stringify([
                { key: 'residence_country', value: ['US', 'UK', 'IN', 'CA'][userId % 4] },
                { key: 'subscription_active', value: '1' },
                { key: 'profile_pic_url', value: `https://example.com/pic_${userId}.jpg` }
            ]);

            const userPreferences = JSON.stringify([
                { preference: 'country', value: (userId % 5) + 1 },
                { preference: 'team_1', value: (userId % 20) + 1 },
                { preference: 'team_2', value: (userId % 20) + 1 },
                { preference: 'tnc', value: 1 }
            ]);

            const batchPromise = async () => {
                try {
                    const userStmt = api.db.preparedStatements.get('insertUser');
                    const lookupStmt = api.db.preparedStatements.get('insertUserBySource');
                    
                    const statements = [
                        {
                            query: userStmt,
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
                            query: lookupStmt,
                            params: [
                                userData.partitionId, userData.sourceId, userData.userId,
                                cassandra.types.Uuid.fromString(userData.userGuid), 
                                userData.loginPlatformSource, now
                            ]
                        }
                    ];
                    
                    await api.db.executeBatch(statements);
                } catch (error) {
                    console.error(`Failed to create user ${userId}:`, error.message);
                }
            };
            
            batchPromises.push(batchPromise());
        }
        
        await Promise.all(batchPromises);
        
        if (i % 500 === 0 || endIndex === numUsers) {
            console.log(`📊 Created ${endIndex}/${numUsers} users (${Math.round(endIndex / numUsers * 100)}%)`.green);
        }
    }
    
    console.log(`✅ Successfully created ${usersData.length} users with optimized batching`.green);
    return usersData;
}

// ====================================================================
// OPTIMIZED PERFORMANCE TESTING - REGULAR AND HIGH-LOAD
// ====================================================================

async function runPerformanceTestsOptimized(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} optimized performance tests...`.cyan);
    const controller = new EnhancedConcurrencyController(15, 2000);
    const testPromises = [];
    const batchSize = Math.min(500, Math.max(50, Math.floor(numTests / 100)));

    for (let i = 0; i < numTests; i += batchSize) {
        const batchPromises = [];
        const endIndex = Math.min(i + batchSize, numTests);

        for (let j = i; j < endIndex; j++) {
            const testPromise = controller.execute(async () => {
                const userData = usersData[j % usersData.length];
                
                try {
                    const loginResult = await api.userLogin(userData.sourceId, userData.deviceId, userData.loginPlatformSource);
                    
                    if (loginResult.success) {
                        await api.getUserProfile(userData.userId, userData.partitionId);

                        const teamData = generateTeamDataOptimized(userData, (j % 3) + 1);
                        const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);
                        
                        if (saveResult.success) {
                            const teamsResult = await api.getUserTeams(userData, CURRENT_GAMESET);
                            
                            if (j % 10 === 0 && teamsResult && teamsResult.teams.length > 0) {
                                const currentTeam = await api.getCurrentTeamState(userData, teamData.teamNo);
                                if (currentTeam) {
                                    const transferData = generateValidTransferData(currentTeam);
                                    
                                    if (transferData.entitiesIn.length > 0 && transferData.entitiesOut.length > 0) {
                                        const transferResult = await api.transferTeamOptimized(
                                            userData, teamData.teamNo, 
                                            transferData.entitiesIn, transferData.entitiesOut, 
                                            CURRENT_GAMESET, CURRENT_GAMEDAY,
                                            teamData.captainPlayerId, teamData.viceCaptainPlayerId
                                        );
                                        
                                        if (!transferResult.success && transferResult.errorCode !== 'TRANSFER_LIMIT_EXCEEDED') {
                                            console.log(`⚠️ Transfer validation failed: ${transferResult.errorCode} - ${transferResult.error}`.yellow);
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        console.log(`⚠️ User login failed for ${userData.sourceId}`.yellow);
                    }
                } catch (error) {
                    console.error(`Test ${j} execution error:`, error.message);
                }
            });
            batchPromises.push(testPromise);
        }
        
        await Promise.allSettled(batchPromises);

        const stats = controller.getStats();
        console.log(`⏱️ Progress: ${endIndex}/${numTests} (${stats.running} running, ${stats.queued} queued)`.cyan);
    }
    
    console.log('✅ Optimized performance tests completed'.green);
}

async function runHighLoadPerformanceTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} high-load performance tests...`.cyan);
    
    const controller = new EnhancedConcurrencyController(8, 1500, 30);
    const testPromises = [];
    const batchSize = Math.min(1000, Math.max(100, Math.floor(numTests / 100)));
    
    for (let i = 0; i < numTests; i += batchSize) {
        const batchPromises = [];
        const endIndex = Math.min(i + batchSize, numTests);
        
        for (let j = i; j < endIndex; j++) {
            const testPromise = controller.execute(async () => {
                const userData = usersData[j % usersData.length];
                
                let retryCount = 0;
                const maxRetries = 3;
                
                while (retryCount < maxRetries) {
                    try {
                        const teamData = generateTeamDataOptimized(userData, (j % 3) + 1);
                        const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);
                        
                        if (saveResult.success) {
                            if (j % 20 === 0) {
                                const currentTeam = await api.getCurrentTeamState(userData, teamData.teamNo);
                                if (currentTeam) {
                                    const transferData = generateValidTransferData(currentTeam);
                                    
                                    if (transferData.entitiesIn.length > 0 && transferData.entitiesOut.length > 0) {
                                        await api.transferTeamOptimized(
                                            userData, teamData.teamNo, 
                                            transferData.entitiesIn, transferData.entitiesOut, 
                                            CURRENT_GAMESET, CURRENT_GAMEDAY,
                                            teamData.captainPlayerId, teamData.viceCaptainPlayerId
                                        );
                                    }
                                }
                            }
                        }
                        break;
                    } catch (error) {
                        retryCount++;
                        if (retryCount >= maxRetries) {
                            console.error(`Test ${j} failed after ${maxRetries} retries:`, error.message);
                            break;
                        }
                        await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1000));
                    }
                }
            });
            
            batchPromises.push(testPromise);
        }
        
        await Promise.allSettled(batchPromises);
        
        const stats = controller.getStats();
        console.log(`⏱️ Progress: ${endIndex}/${numTests} (${stats.running} running, ${stats.queued} queued, ${stats.errors} errors, CB: ${stats.circuitOpen ? 'OPEN' : 'CLOSED'})`.cyan);
        
        if (endIndex < numTests) {
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    console.log('✅ High-load performance tests completed'.green);
}

// ====================================================================
// ENHANCED PERFORMANCE REPORTING
// ====================================================================

function generateEnhancedPerformanceReport() {
    const report = {
        timestamp: new Date().toISOString(),
        summary: {},
        detailedStats: {},
        memoryStats: perfMonitor.getMemoryStats()
    };

    const stats = perfMonitor.getStats();
    
    Object.entries(stats).forEach(([operation, times]) => {
        if (operation === 'errors' || operation === 'transferValidationErrors' || times.length === 0) return;

        times.sort((a, b) => a - b);
        const avg = times.reduce((sum, time) => sum + time, 0) / times.length;
        const median = times[Math.floor(times.length / 2)];
        const min = times[0];
        const max = times[times.length - 1];
        const p95 = times[Math.floor(times.length * 0.95)] || 'N/A';
        const p99 = times[Math.floor(times.length * 0.99)] || 'N/A';

        const operationStats = {
            operation,
            totalCalls: times.length,
            avgTimeMs: Math.round(avg * 100) / 100,
            medianTimeMs: Math.round(median * 100) / 100,
            minTimeMs: Math.round(min * 100) / 100,
            maxTimeMs: Math.round(max * 100) / 100,
            p95TimeMs: p95 !== 'N/A' ? Math.round(p95 * 100) / 100 : 'N/A',
            p99TimeMs: p99 !== 'N/A' ? Math.round(p99 * 100) / 100 : 'N/A'
        };

        report.detailedStats[operation] = operationStats;
        report.summary[operation] = `${operationStats.avgTimeMs}ms avg, ${operationStats.totalCalls} calls`;
    });

    const totalOperations = Object.values(stats)
        .filter(times => Array.isArray(times) && times.length > 0)
        .reduce((sum, times) => sum + times.length, 0);

    report.errors = {
        totalErrors: stats.errors.length,
        transferValidationErrors: stats.transferValidationErrors.length,
        errorRate: totalOperations > 0
            ? `${((stats.errors.length / totalOperations) * 100).toFixed(2)}%`
            : '0%'
    };

    return report;
}

function printEnhancedPerformanceReport(report) {
    console.log('\n' + '='.repeat(80).yellow);
    console.log('FANTASY GAME CASSANDRA POC - ENHANCED PERFORMANCE REPORT'.bold.yellow);
    console.log('='.repeat(80).yellow);
    console.log(`Generated: ${report.timestamp}`.cyan);
    console.log(`Total Errors: ${report.errors.totalErrors} (${report.errors.errorRate})`.red);
    console.log(`Transfer Validation Errors: ${report.errors.transferValidationErrors}`.yellow);
    console.log(`Memory Usage: ${Math.round(report.memoryStats.memory.heapUsed / 1024 / 1024)}MB heap`.blue);
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
// MAIN EXECUTION WITH ENHANCED ERROR HANDLING
// ====================================================================

async function main() {
    program
        .option('--users <number>', 'Number of users to create', DEFAULT_USERS)
        .option('--tests <number>', 'Number of performance tests to run', DEFAULT_TESTS)
        .option('--skip-data', 'Skip test data generation')
        .option('--report-file <file>', 'Save performance report to file')
        .option('--high-load', 'Enable high-load optimizations')
        .parse(process.argv);

    const options = program.opts();
    const numUsers = parseInt(options.users);
    const numTests = parseInt(options.tests);

    console.log('🎮 Starting Complete Optimized Fantasy Game Cassandra POC'.bold.cyan);
    console.log(`📊 Configuration: ${numUsers} users, ${numTests} tests`.gray);
    
    const highLoadMode = options.highLoad || false;
    if (options.highLoad || numUsers > 10000 || numTests > 50000) {
        console.log('⚡ High-load mode enabled'.yellow);
    }

    const cassandraConn = new CassandraConnection(highLoadMode);

    let maxRetries = 3;
    let connected = false;
    
    for (let retry = 0; retry < maxRetries; retry++) {
        if (await cassandraConn.connect()) {
            connected = true;
            break;
        }
        if (retry < maxRetries - 1) {
            console.log(`⏳ Retrying connection in 5 seconds... (${retry + 1}/${maxRetries})`.yellow);
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }

    if (!connected) {
        console.error('❌ Failed to connect to Cassandra after retries. Exiting.'.red);
        process.exit(1);
    }

    try {
        const api = new FantasyGameAPI(cassandraConn);

        let usersData;
        if (!options.skipData) {
            if (numUsers > 10000) {
                console.log(`⚠️ WARNING: Creating ${numUsers} users will take significant time. Consider using --skip-data for large tests.`.yellow);
            }
            usersData = await populateTestDataOptimized(api, numUsers);
        } else {
            console.log(`📊 Generating user data structures for ${numUsers} users (no database inserts)...`.cyan);
            usersData = Array.from({ length: numUsers }, (_, i) => generateUserData(i + 1));
            console.log(`✅ Generated ${usersData.length} user data structures`.green);
        }

        console.log('⏱️ Starting optimized performance tests...'.cyan);
        const startTime = Date.now();
        
        if (highLoadMode) {
            await runHighLoadPerformanceTests(api, usersData, numTests);
        } else {
            await runPerformanceTestsOptimized(api, usersData, numTests);
        }
        
        const totalTestTime = Date.now() - startTime;

        const report = generateEnhancedPerformanceReport();
        report.testDurationSeconds = Math.round(totalTestTime / 1000 * 100) / 100;
        report.throughputOpsPerSecond = Math.round((numTests / (totalTestTime / 1000)) * 100) / 100;

        printEnhancedPerformanceReport(report);

        if (options.reportFile) {
            await fs.writeFile(options.reportFile, JSON.stringify(report, null, 2));
            console.log(`💾 Performance report saved to ${options.reportFile}`.green);
        }

        console.log('🎉 Complete optimized POC testing completed successfully'.bold.green);
    } catch (error) {
        console.error('❌ POC testing failed:'.red, error.message);
        throw error;
    } finally {
        await cassandraConn.shutdown();
    }
}

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

module.exports = { main, FantasyGameAPI, CassandraConnection };
