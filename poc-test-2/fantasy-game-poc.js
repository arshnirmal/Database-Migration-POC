#!/usr/bin/env node

/**
 * Fantasy Game ScyllaDB POC Testing Script - Complete Optimized Version with ALL APIs
 * ==================================================================================
 *
 * This script includes ALL APIs from the Cassandra POC plus ScyllaDB optimizations:
 * - ALL API methods from the original Cassandra POC
 * - ScyllaDB-specific connection optimizations
 * - Enhanced concurrency handling for ScyllaDB's performance
 * - ScyllaDB-aware circuit breaker and health monitoring
 * - High-throughput batch operations
 * - Comprehensive performance metrics and reporting
 *
 * Usage:
 * node fantasy-game-scylladb-poc-complete.js --users 1000 --tests 500
 * node fantasy-game-scylladb-poc-complete.js --users 10000 --tests 25000 --skip-data --high-load
 */

const cassandra = require('cassandra-driver');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs').promises;
const path = require('path');
const { program } = require('commander');
const colors = require('colors');

// ====================================================================
// SCYLLADB-OPTIMIZED CONFIGURATION
// ====================================================================

const SCYLLADB_CONFIG = {
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
        maxRequestsPerConnection: 32768,
        heartBeatInterval: 30000
    },
    socketOptions: {
        readTimeout: 10000,        // Reduced - ScyllaDB is faster
        connectTimeout: 5000,      // Reduced - ScyllaDB connects faster
        keepAlive: true,
        keepAliveDelay: 0,
        tcpNoDelay: true          // Important for ScyllaDB performance
    },
    queryOptions: {
        consistency: cassandra.types.consistencies.localQuorum, // Better for 3-node cluster
        prepare: true,
        autoPage: false,
        fetchSize: 1000           // Larger fetch sizes work well with ScyllaDB
    },
    policies: {
        retry: new cassandra.policies.retry.IdempotenceAwareRetryPolicy(
            new cassandra.policies.retry.RetryPolicy()
        ),
        reconnection: new cassandra.policies.reconnection.ExponentialReconnectionPolicy(500, 5000)
    }
};

const HIGH_LOAD_SCYLLADB_CONFIG = {
    ...SCYLLADB_CONFIG,
    pooling: {
        coreConnectionsPerHost: {
            [cassandra.types.distance.local]: 8,
            [cassandra.types.distance.remote]: 4
        },
        maxConnectionsPerHost: {
            [cassandra.types.distance.local]: 32,
            [cassandra.types.distance.remote]: 8
        },
        maxRequestsPerConnection: 65536,
        heartBeatInterval: 60000
    },
    socketOptions: {
        ...SCYLLADB_CONFIG.socketOptions,
        readTimeout: 15000,
        connectTimeout: 8000
    },
    queryOptions: {
        ...SCYLLADB_CONFIG.queryOptions,
        fetchSize: 2000
    }
};

const DEFAULT_USERS = 1000;
const DEFAULT_TESTS = 100;
const CURRENT_SEASON = 2024;
const CURRENT_GAMESET = 15;
const CURRENT_GAMEDAY = 3;

// ====================================================================
// SCYLLADB-ENHANCED PERFORMANCE METRICS
// ====================================================================

class ScyllaDBPerformanceMonitor {
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
        
        // ScyllaDB-specific metrics
        this.scyllaMetrics = {
            nodeLatencies: new Map(),
            throughputHistory: [],
            peakThroughput: 0,
            avgLatency: 0,
            operationCount: 0
        };
    }

    startOperation(operationName, identifier = '') {
        const key = `${operationName}_${identifier}_${Date.now()}_${Math.random()}`;
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
        this.updateScyllaMetrics(result);
        return result;
    }

    logMetric(result) {
        if (!this.operationStats[result.operation]) {
            this.operationStats[result.operation] = [];
        }
        this.operationStats[result.operation].push(result.duration);
    }

    updateScyllaMetrics(result) {
        this.scyllaMetrics.operationCount++;
        
        // Update average latency
        const totalLatency = this.scyllaMetrics.avgLatency * (this.scyllaMetrics.operationCount - 1) + result.duration;
        this.scyllaMetrics.avgLatency = totalLatency / this.scyllaMetrics.operationCount;
        
        // Track throughput every second
        const now = Date.now();
        const secondBucket = Math.floor(now / 1000);
        
        const history = this.scyllaMetrics.throughputHistory;
        if (history.length === 0 || history[history.length - 1].second !== secondBucket) {
            history.push({ second: secondBucket, operations: 1 });
        } else {
            history[history.length - 1].operations++;
        }
        
        // Keep only last 60 seconds
        if (history.length > 60) {
            history.shift();
        }
        
        // Update peak throughput
        const currentThroughput = history[history.length - 1].operations;
        if (currentThroughput > this.scyllaMetrics.peakThroughput) {
            this.scyllaMetrics.peakThroughput = currentThroughput;
        }
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

    getScyllaMetrics() {
        return {
            ...this.scyllaMetrics,
            currentThroughput: this.scyllaMetrics.throughputHistory.length > 0 
                ? this.scyllaMetrics.throughputHistory[this.scyllaMetrics.throughputHistory.length - 1].operations 
                : 0
        };
    }
}

const perfMonitor = new ScyllaDBPerformanceMonitor();

// ====================================================================
// COMPLETE FANTASY FOOTBALL DATA (SAME AS CASSANDRA POC)
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
// PLAYER POOL CLASS (IDENTICAL TO CASSANDRA POC)
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
// SCYLLADB-ENHANCED CONCURRENCY CONTROLLER
// ====================================================================

class ScyllaDBConcurrencyController {
    constructor(maxConcurrency = 25, queueLimit = 5000, circuitBreakerThreshold = 100) {
        this.maxConcurrency = maxConcurrency;        // Higher - ScyllaDB handles more
        this.queueLimit = queueLimit;                // Increased queue
        this.running = 0;
        this.queue = [];
        this.completed = 0;
        this.errors = 0;
        this.circuitBreakerThreshold = circuitBreakerThreshold;
        this.circuitOpen = false;
        this.lastErrorTime = 0;
        this.circuitResetTimeout = 15000;           // Faster reset for ScyllaDB
        
        // ScyllaDB-specific metrics
        this.scyllaMetrics = {
            avgLatency: 0,
            throughput: 0,
            lastThroughputCheck: Date.now(),
            operationsInLastSecond: 0,
            peakConcurrency: 0
        };
    }

    updateThroughputMetrics() {
        const now = Date.now();
        if (now - this.scyllaMetrics.lastThroughputCheck >= 1000) {
            this.scyllaMetrics.throughput = this.scyllaMetrics.operationsInLastSecond;
            this.scyllaMetrics.operationsInLastSecond = 0;
            this.scyllaMetrics.lastThroughputCheck = now;
        }
    }

    async execute(taskFn) {
        if (this.circuitOpen) {
            if (Date.now() - this.lastErrorTime > this.circuitResetTimeout) {
                this.circuitOpen = false;
                this.errors = 0;
                console.log('🔄 ScyllaDB circuit breaker reset - resuming operations'.green);
            } else {
                throw new Error('ScyllaDB circuit breaker is open - too many errors');
            }
        }

        return new Promise((resolve, reject) => {
            if (this.queue.length >= this.queueLimit) {
                reject(new Error('ScyllaDB queue limit exceeded'));
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
        
        // Update peak concurrency
        if (this.running > this.scyllaMetrics.peakConcurrency) {
            this.scyllaMetrics.peakConcurrency = this.running;
        }
        
        const { taskFn, resolve, reject } = this.queue.shift();
        
        try {
            const startTime = Date.now();
            const result = await taskFn();
            
            // Update ScyllaDB-specific metrics
            const duration = Date.now() - startTime;
            this.scyllaMetrics.avgLatency = 
                (this.scyllaMetrics.avgLatency + duration) / 2;
            this.scyllaMetrics.operationsInLastSecond++;
            this.updateThroughputMetrics();
            
            resolve(result);
            this.completed++;
        } catch (error) {
            this.errors++;
            this.lastErrorTime = Date.now();
            
            if (this.errors >= this.circuitBreakerThreshold) {
                this.circuitOpen = true;
                console.log('⚡ ScyllaDB circuit breaker opened - too many errors'.red);
            }
            
            reject(error);
        } finally {
            this.running--;
            setImmediate(() => this.processQueue());
        }
    }

    getScyllaStats() {
        return {
            running: this.running,
            queued: this.queue.length,
            completed: this.completed,
            errors: this.errors,
            circuitOpen: this.circuitOpen,
            avgLatencyMs: Math.round(this.scyllaMetrics.avgLatency),
            throughputOpsPerSec: this.scyllaMetrics.throughput,
            peakConcurrency: this.scyllaMetrics.peakConcurrency
        };
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
// COMPLETE SCYLLADB CONNECTION CLASS
// ====================================================================

class ScyllaDBConnection {
    constructor(highLoad = false) {
        this.client = null;
        this.preparedStatements = new Map();
        this.config = highLoad ? HIGH_LOAD_SCYLLADB_CONFIG : SCYLLADB_CONFIG;
        this.highLoad = highLoad;
        this.healthCheckInterval = null;
        this.isHealthy = true;
        
        // ScyllaDB-specific properties
        this.scyllaMetrics = {
            nodeHealth: new Map(),
            shardAwareness: false,
            version: null,
            connectedNodes: 0
        };
    }

    async connect() {
        try {
            this.client = new cassandra.Client(this.config);
            await this.client.connect();
            
            // Verify ScyllaDB-specific features
            await this.verifyScyllaDBFeatures();
            
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
            console.log(`✅ Connected to ScyllaDB cluster with ${mode} settings`.green);
            console.log(`🚀 ScyllaDB version: ${this.scyllaMetrics.version || 'Unknown'}`.cyan);
            console.log(`🔥 Shard-aware: ${this.scyllaMetrics.shardAwareness ? 'Yes' : 'No'}`.cyan);
            console.log(`🌐 Connected nodes: ${this.scyllaMetrics.connectedNodes}`.cyan);
            
            await this.prepareCQLStatements();
            if (this.highLoad) {
                this.startScyllaDBHealthCheck();
            }

            return true;
        } catch (error) {
            console.error('❌ Failed to connect to ScyllaDB:'.red, error.message);
            return false;
        }
    }

    async verifyScyllaDBFeatures() {
        try {
            // Check if we're connected to ScyllaDB (not Cassandra)
            const result = await this.client.execute("SELECT release_version FROM system.local");
            const version = result.rows[0]?.release_version;
            
            if (version) {
                this.scyllaMetrics.version = version;
                if (version.includes('ScyllaDB') || version.includes('Scylla')) {
                    console.log(`🚀 Verified ScyllaDB connection: ${version}`.green);
                    this.scyllaMetrics.shardAwareness = true;
                } else {
                    console.log(`⚠️ Connected to Cassandra, not ScyllaDB: ${version}`.yellow);
                }
            }
            
            // Get node count
            const peers = await this.client.execute("SELECT peer FROM system.peers");
            this.scyllaMetrics.connectedNodes = peers.rows.length + 1; // +1 for local node
            
        } catch (error) {
            console.log('🔍 Could not verify ScyllaDB features (continuing anyway)'.gray);
        }
    }

    startScyllaDBHealthCheck() {
        this.healthCheckInterval = setInterval(async () => {
            try {
                // ScyllaDB-specific health check with timing
                const start = Date.now();
                await this.client.execute('SELECT now() FROM system.local');
                const latency = Date.now() - start;
                
                if (!this.isHealthy) {
                    this.isHealthy = true;
                    console.log(`✅ ScyllaDB connection restored (${latency}ms latency)`.green);
                }
                
                // Update node health metrics
                this.scyllaMetrics.nodeHealth.set('primary', {
                    latency,
                    timestamp: Date.now(),
                    healthy: true
                });
                
            } catch (error) {
                if (this.isHealthy) {
                    this.isHealthy = false;
                    console.error('❌ ScyllaDB health check failed:'.red, error.message);
                }
                
                this.scyllaMetrics.nodeHealth.set('primary', {
                    latency: -1,
                    timestamp: Date.now(),
                    healthy: false,
                    error: error.message
                });
            }
        }, 5000); // More frequent checks for ScyllaDB
    }

    async executeBatch(statements) {
        if (this.highLoad && !this.isHealthy) {
            throw new Error('ScyllaDB connection is unhealthy');
        }

        try {
            const queries = statements.map(stmt => ({
                query: stmt.query,
                params: stmt.params
            }));
            
            const options = {
                prepare: true,
                consistency: cassandra.types.consistencies.localQuorum // Better for 3-node
            };
            
            if (this.highLoad) {
                options.retry = true;
                options.idempotent = true; // ScyllaDB optimization
            }

            return await this.client.batch(queries, options);
        } catch (error) {
            console.error('ScyllaDB batch execution failed:', error.message);
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

        console.log('✅ ScyllaDB prepared statements created successfully'.green);
    }

    getScyllaDBMetrics() {
        return {
            isHealthy: this.isHealthy,
            shardAware: this.scyllaMetrics.shardAwareness,
            version: this.scyllaMetrics.version,
            connectedNodes: this.scyllaMetrics.connectedNodes,
            nodeHealth: Object.fromEntries(this.scyllaMetrics.nodeHealth),
            connectionPool: {
                maxConnections: this.config.pooling?.maxConnectionsPerHost?.[cassandra.types.distance.local] || 'N/A'
            }
        };
    }

    async shutdown() {
        if (this.healthCheckInterval) {
            clearInterval(this.healthCheckInterval);
        }

        if (this.client) {
            await this.client.shutdown();
            console.log('🔌 Disconnected from ScyllaDB'.yellow);
        }
    }
}

// ====================================================================
// ALL UTILITY FUNCTIONS (IDENTICAL TO CASSANDRA POC)
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
// ALL VALIDATION FUNCTIONS (IDENTICAL TO CASSANDRA POC)
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
// COMPLETE FANTASY GAME API CLASS - ALL METHODS FROM CASSANDRA POC
// ====================================================================

class FantasyGameAPI {
    constructor(scyllaConn) {
        this.db = scyllaConn;
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
                        user_preferences: userPreferences,
                        created_date: now
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
// COMPLETE BATCH OPERATIONS (IDENTICAL TO CASSANDRA POC)
// ====================================================================

async function populateScyllaDBTestData(api, numUsers) {
    console.log(`🔄 Generating ScyllaDB test data for ${numUsers} users with optimized batching...`.cyan);
    
    const usersData = [];
    const batchSize = 75; // Larger batches for ScyllaDB
    
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
        
        if (i % 1000 === 0 || endIndex === numUsers) {
            console.log(`📊 Created ${endIndex}/${numUsers} users (${Math.round(endIndex / numUsers * 100)}%)`.green);
        }
    }
    
    console.log(`✅ Successfully created ${usersData.length} users with ScyllaDB-optimized batching`.green);
    return usersData;
}

// ====================================================================
// ALL PERFORMANCE TESTING FUNCTIONS (ENHANCED FOR SCYLLADB)
// ====================================================================

async function runScyllaDBPerformanceTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} ScyllaDB-optimized performance tests with ALL APIs...`.cyan);
    
    const controller = new ScyllaDBConcurrencyController(25, 3000);
    const testPromises = [];
    const batchSize = Math.min(1000, Math.max(100, Math.floor(numTests / 50)));
    
    for (let i = 0; i < numTests; i += batchSize) {
        const batchPromises = [];
        const endIndex = Math.min(i + batchSize, numTests);
        
        for (let j = i; j < endIndex; j++) {
            const testPromise = controller.execute(async () => {
                const userData = usersData[j % usersData.length];
                try {
                    // 1. USER LOGIN - Same as Cassandra POC
                    const loginResult = await api.userLogin(
                        userData.sourceId, 
                        userData.deviceId, 
                        userData.loginPlatformSource
                    );
                    
                    if (loginResult.success) {
                        // 2. GET USER PROFILE - Same as Cassandra POC  
                        await api.getUserProfile(userData.userId, userData.partitionId);
                        
                        // 3. SAVE TEAM - Same as Cassandra POC
                        const teamData = generateTeamDataOptimized(userData, (j % 3) + 1);
                        const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);
                        
                        if (saveResult.success) {
                            // 4. GET USER TEAMS - Same as Cassandra POC
                            const teamsResult = await api.getUserTeams(userData, CURRENT_GAMESET);
                            
                            // 5. TRANSFER TEAM - Same frequency as Cassandra POC
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
                    console.error(`ScyllaDB test ${j} execution error:`, error.message);
                }
            });
            
            batchPromises.push(testPromise);
        }

        await Promise.allSettled(batchPromises);
        
        const stats = controller.getScyllaStats();
        console.log(`⏱️ Progress: ${endIndex}/${numTests} (${stats.running} running, ${stats.queued} queued)`.cyan);
        
        if (endIndex < numTests) {
            await new Promise(resolve => setTimeout(resolve, 50));
        }
    }

    console.log('✅ ScyllaDB performance tests completed with ALL APIs'.green);
    return controller.getScyllaStats();
}


async function runHighLoadScyllaDBTests(api, usersData, numTests) {
    console.log(`🚀 Running ${numTests} high-load ScyllaDB performance tests with ALL APIs...`.cyan);
    const controller = new ScyllaDBConcurrencyController(40, 5000, 150);
    const testPromises = [];
    const batchSize = Math.min(2000, Math.max(200, Math.floor(numTests / 25)));
    
    for (let i = 0; i < numTests; i += batchSize) {
        const batchPromises = [];
        const endIndex = Math.min(i + batchSize, numTests);
        
        for (let j = i; j < endIndex; j++) {
            const testPromise = controller.execute(async () => {
                const userData = usersData[j % usersData.length];
                let retryCount = 0;
                const maxRetries = 2;
                
                while (retryCount < maxRetries) {
                    try {
                        // 1. USER LOGIN - ADDED BACK
                        const loginResult = await api.userLogin(
                            userData.sourceId, 
                            userData.deviceId, 
                            userData.loginPlatformSource
                        );
                        
                        if (loginResult.success) {
                            // 2. GET USER PROFILE - ADDED BACK
                            await api.getUserProfile(userData.userId, userData.partitionId);
                            
                            // 3. SAVE TEAM
                            const teamData = generateTeamDataOptimized(userData, (j % 3) + 1);
                            const saveResult = await api.saveTeam(userData, teamData, CURRENT_GAMESET, CURRENT_GAMEDAY);
                            
                            if (saveResult.success) {
                                // 4. GET USER TEAMS - ADDED BACK
                                const teamsResult = await api.getUserTeams(userData, CURRENT_GAMESET);
                                
                                // 5. TRANSFER TEAM - Keep high-load frequency
                                if (j % 20 === 0 && teamsResult && teamsResult.teams.length > 0) {
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
                        } else {
                            console.log(`⚠️ User login failed for ${userData.sourceId}`.yellow);
                        }
                        break;
                    } catch (error) {
                        retryCount++;
                        if (retryCount >= maxRetries) {
                            console.error(`High-load test ${j} failed after ${maxRetries} retries:`, error.message);
                            break;
                        }
                        await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 500));
                    }
                }
            });
            
            batchPromises.push(testPromise);
        }

        await Promise.allSettled(batchPromises);
        
        const stats = controller.getScyllaStats();
        console.log(
            `⏱️ Progress: ${endIndex}/${numTests} ` +
            `(${stats.running} running, ${stats.queued} queued, ` +
            `${stats.errors} errors, CB: ${stats.circuitOpen ? 'OPEN' : 'CLOSED'})`.cyan
        );
        
        if (endIndex < numTests) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }

    console.log('✅ High-load ScyllaDB performance tests completed with ALL APIs'.green);
    return controller.getScyllaStats();
}


// ====================================================================
// COMPLETE PERFORMANCE REPORTING (ENHANCED FROM CASSANDRA POC)
// ====================================================================

function generateScyllaDBPerformanceReport(scyllaStats) {
    const baseReport = generateEnhancedPerformanceReport();
    const scyllaMetrics = perfMonitor.getScyllaMetrics();
    
    return {
        ...baseReport,
        database: 'ScyllaDB',
        scyllaSpecificMetrics: {
            avgLatencyMs: scyllaStats.avgLatencyMs || scyllaMetrics.avgLatency,
            peakThroughputOpsPerSec: scyllaStats.throughputOpsPerSec || scyllaMetrics.peakThroughput,
            currentThroughputOpsPerSec: scyllaMetrics.currentThroughput,
            circuitBreakerTriggered: scyllaStats.circuitOpen,
            peakConcurrency: scyllaStats.peakConcurrency,
            totalOperations: scyllaMetrics.operationCount
        },
        performance: {
            ...baseReport.performance,
            scyllaOptimizations: {
                shardAwareness: 'Enabled',
                batchOptimization: 'Enhanced for ScyllaDB',
                concurrencyLevel: `High (${scyllaStats.peakConcurrency || 25} peak concurrent)`,
                consistencyLevel: 'LOCAL_QUORUM',
                connectionPooling: 'ScyllaDB-Optimized',
                circuitBreaker: scyllaStats.circuitOpen ? 'OPEN' : 'CLOSED'
            }
        }
    };
}

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

function printScyllaDBPerformanceReport(report) {
    console.log('\n' + '='.repeat(80).cyan);
    console.log('FANTASY GAME SCYLLADB POC - COMPLETE PERFORMANCE REPORT'.bold.cyan);
    console.log('='.repeat(80).cyan);
    console.log(`Database: ${report.database}`.green);
    console.log(`Generated: ${report.timestamp}`.gray);
    
    if (report.scyllaSpecificMetrics) {
        console.log('\nSCYLLADB SPECIFIC METRICS:'.bold.yellow);
        console.log('-'.repeat(35).yellow);
        console.log(`Average Latency: ${report.scyllaSpecificMetrics.avgLatencyMs}ms`.white);
        console.log(`Peak Throughput: ${report.scyllaSpecificMetrics.peakThroughputOpsPerSec} ops/sec`.white);
        console.log(`Current Throughput: ${report.scyllaSpecificMetrics.currentThroughputOpsPerSec || 0} ops/sec`.white);
        console.log(`Peak Concurrency: ${report.scyllaSpecificMetrics.peakConcurrency}`.white);
        console.log(`Total Operations: ${report.scyllaSpecificMetrics.totalOperations}`.white);
        console.log(`Circuit Breaker: ${report.scyllaSpecificMetrics.circuitBreakerTriggered ? 'TRIGGERED'.red : 'OK'.green}`.white);
    }
    
    console.log(`\nTotal Errors: ${report.errors.totalErrors} (${report.errors.errorRate})`.red);
    console.log(`Transfer Validation Errors: ${report.errors.transferValidationErrors}`.yellow);
    console.log(`Memory Usage: ${Math.round(report.memoryStats.memory.heapUsed / 1024 / 1024)}MB heap`.blue);

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
    
    console.log('\nSCYLLADB OPTIMIZATIONS ACTIVE:'.bold.green);
    console.log('-'.repeat(40).green);
    Object.entries(report.performance.scyllaOptimizations || {}).forEach(([key, value]) => {
        console.log(`${key.replace(/([A-Z])/g, ' $1').toUpperCase()}: ${value}`.white);
    });
    
    console.log('\n' + '='.repeat(80).cyan);
}

// ====================================================================
// COMPLETE MAIN EXECUTION (IDENTICAL TO CASSANDRA POC LOGIC)
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

    console.log('🎮 Starting Complete ScyllaDB Fantasy Game POC with ALL APIs'.bold.cyan);
    console.log(`📊 Configuration: ${numUsers} users, ${numTests} tests`.gray);

    const highLoadMode = options.highLoad || numUsers > 10000 || numTests > 50000;
    if (highLoadMode) {
        console.log('⚡ High-load ScyllaDB mode enabled'.yellow);
    }

    const scyllaConn = new ScyllaDBConnection(highLoadMode);
    let maxRetries = 3;
    let connected = false;
    
    for (let retry = 0; retry < maxRetries; retry++) {
        if (await scyllaConn.connect()) {
            connected = true;
            break;
        }

        if (retry < maxRetries - 1) {
            console.log(`⏳ Retrying ScyllaDB connection in 5 seconds... (${retry + 1}/${maxRetries})`.yellow);
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }

    if (!connected) {
        console.error('❌ Failed to connect to ScyllaDB after retries. Exiting.'.red);
        process.exit(1);
    }

    try {
        const api = new FantasyGameAPI(scyllaConn);
        let usersData;
        let scyllaStats;

        if (!options.skipData) {
            if (numUsers > 10000) {
                console.log(`⚠️ WARNING: Creating ${numUsers} users will take significant time. Consider using --skip-data for large tests.`.yellow);
            }

            usersData = await populateScyllaDBTestData(api, numUsers);
        } else {
            console.log(`📊 Generating user data structures for ${numUsers} users (no database inserts)...`.cyan);
            usersData = Array.from({ length: numUsers }, (_, i) => generateUserData(i + 1));
            console.log(`✅ Generated ${usersData.length} user data structures`.green);
        }

        console.log('⏱️ Starting complete ScyllaDB-optimized performance tests...'.cyan);
        const startTime = Date.now();
        
        if (highLoadMode) {
            scyllaStats = await runHighLoadScyllaDBTests(api, usersData, numTests);
        } else {
            scyllaStats = await runScyllaDBPerformanceTests(api, usersData, numTests);
        }

        const totalTestTime = Date.now() - startTime;
        const report = generateScyllaDBPerformanceReport(scyllaStats);
        report.testDurationSeconds = Math.round(totalTestTime / 1000 * 100) / 100;
        report.throughputOpsPerSecond = Math.round((numTests / (totalTestTime / 1000)) * 100) / 100;
        
        // Add ScyllaDB connection metrics
        report.scyllaConnectionMetrics = scyllaConn.getScyllaDBMetrics();

        printScyllaDBPerformanceReport(report);

        if (options.reportFile) {
            await fs.writeFile(options.reportFile, JSON.stringify(report, null, 2));
            console.log(`💾 Complete ScyllaDB performance report saved to ${options.reportFile}`.green);
        }

        console.log('🎉 Complete ScyllaDB Fantasy Game POC with ALL APIs completed successfully'.bold.green);
    } catch (error) {
        console.error('❌ ScyllaDB POC testing failed:'.red, error.message);
        throw error;
    } finally {
        await scyllaConn.shutdown();
    }
}

process.on('SIGINT', async () => {
    console.log('\n🛑 Received SIGINT, shutting down ScyllaDB connections gracefully...'.yellow);
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\n🛑 Received SIGTERM, shutting down ScyllaDB connections gracefully...'.yellow);
    process.exit(0);
});

if (require.main === module) {
    main().catch(error => {
        console.error('💥 Fatal ScyllaDB POC error:'.red, error);
        process.exit(1);
    });
}

module.exports = { main, FantasyGameAPI, ScyllaDBConnection };
