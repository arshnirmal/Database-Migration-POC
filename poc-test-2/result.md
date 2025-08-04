================================================================================
FANTASY GAME SCYLLADB POC - PERFORMANCE REPORT
================================================================================
Database: ScyllaDB
Generated: 2025-08-04T18:31:08.611Z

SCYLLADB SPECIFIC METRICS:
-----------------------------------
Average Latency: 43ms
Peak Throughput: 893 ops/sec
Current Throughput: 852 ops/sec
Peak Concurrency: 40
Total Operations: 110000
Circuit Breaker: OK

Total Errors: 0 (0.00%)
Transfer Validation Errors: 0
Memory Usage: 75MB heap

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
SAVETEAM             | 28.22ms avg, 100000 calls
TRANSFERTEAM         | 29.43ms avg, 10000 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
saveTeam        100000   28.22    26.69    5.87     160.75   47.15    64.64   
transferTeam    10000    29.43    28.25    4.28     146.6    48.39    65.51   

SCYLLADB OPTIMIZATIONS ACTIVE:
----------------------------------------
SHARD AWARENESS: Enabled
BATCH OPTIMIZATION: Enhanced for ScyllaDB
CONCURRENCY LEVEL: High (40 peak concurrent)
CONSISTENCY LEVEL: LOCAL_QUORUM
CONNECTION POOLING: ScyllaDB-Optimized
CIRCUIT BREAKER: CLOSED

================================================================================
🎉 Complete ScyllaDB-optimized POC testing completed successfully
🔌 Disconnected from ScyllaDB

================================================================================
FANTASY GAME SCYLLADB POC - COMPLETE PERFORMANCE REPORT
================================================================================
Database: ScyllaDB
Generated: 2025-08-04T19:08:13.762Z

SCYLLADB SPECIFIC METRICS:
-----------------------------------
Average Latency: 45ms
Peak Throughput: 668 ops/sec
Current Throughput: 2234 ops/sec
Peak Concurrency: 40
Total Operations: 505000
Circuit Breaker: OK

Total Errors: 0 (0.00%)
Transfer Validation Errors: 0
Memory Usage: 84MB heap

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 16.86ms avg, 100000 calls
GETUSERPROFILE       | 8.37ms avg, 200000 calls
SAVETEAM             | 24.99ms avg, 100000 calls
GETUSERTEAMS         | 8.57ms avg, 100000 calls
TRANSFERTEAM         | 25.24ms avg, 5000 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       100000   16.86    15.37    3.22     193.32   30.13    39.03   
getUserProfile  200000   8.37     7.65     1.14     182.49   16.06    21.24   
saveTeam        100000   24.99    23.97    5.45     208.42   39.48    49.78   
getUserTeams    100000   8.57     7.85     1.01     185.99   16.23    20.87   
transferTeam    5000     25.24    24.41    4.49     194.23   39.4     50.26   

SCYLLADB OPTIMIZATIONS ACTIVE:
----------------------------------------
SHARD AWARENESS: Enabled
BATCH OPTIMIZATION: Enhanced for ScyllaDB
CONCURRENCY LEVEL: High (40 peak concurrent)
CONSISTENCY LEVEL: LOCAL_QUORUM
CONNECTION POOLING: ScyllaDB-Optimized
CIRCUIT BREAKER: CLOSED

================================================================================
🎉 Complete ScyllaDB Fantasy Game POC with ALL APIs completed successfully
🔌 Disconnected from ScyllaDB