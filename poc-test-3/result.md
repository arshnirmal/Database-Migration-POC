================================================================================
FANTASY GAME COCKROACHDB POC - COMPLETE PERFORMANCE REPORT
================================================================================
Generated: 2025-08-05T20:13:39.112Z
Database: CockroachDB (Refactored - Complete)
Total Errors: 0 (0.00%)

COCKROACHDB SHARD DISTRIBUTION:
--------------------------------------------------
Shard 0: 115669 operations (34.0%)
Shard 1: 112019 operations (32.9%)
Shard 2: 112312 operations (33.0%)
Connection Errors: 0
Total Operations: 340000

OPERATION PERFORMANCE SUMMARY:

COCKROACHDB SHARD DISTRIBUTION:
--------------------------------------------------
Shard 0: 115669 operations (34.0%)
Shard 1: 112019 operations (32.9%)
Shard 2: 112312 operations (33.0%)
Connection Errors: 0
Total Operations: 340000

OPERATION PERFORMANCE SUMMARY:
COCKROACHDB SHARD DISTRIBUTION:
--------------------------------------------------
Shard 0: 115669 operations (34.0%)
Shard 1: 112019 operations (32.9%)
Shard 2: 112312 operations (33.0%)
Connection Errors: 0
Total Operations: 340000

OPERATION PERFORMANCE SUMMARY:
Shard 0: 115669 operations (34.0%)
Shard 1: 112019 operations (32.9%)
Shard 2: 112312 operations (33.0%)
Connection Errors: 0
Total Operations: 340000

OPERATION PERFORMANCE SUMMARY:
Shard 2: 112312 operations (33.0%)
Connection Errors: 0
Total Operations: 340000

OPERATION PERFORMANCE SUMMARY:
Total Operations: 340000

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 57.17ms avg, 120000 calls
GETUSERPROFILE       | 6.62ms avg, 100000 calls
GETUSERTEAMS         | 12.36ms avg, 100000 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       120000   57.17    13       5        859      340      524
getUserProfile  100000   6.62     6        2        37       12       16
getUserTeams    100000   12.36    12       5        73       19       25

================================================================================
🎉 CockroachDB POC testing completed successfully with ALL APIs
✨ All business logic handled in Node.js layer for better maintainability
🔌 Disconnected from CockroachDB cluster

================================================================================
FANTASY GAME COCKROACHDB POC - COMPLETE FIXED PERFORMANCE REPORT
================================================================================
Generated: 2025-08-06T08:26:34.553Z
Database: CockroachDB (Complete Fixed)
Total Errors: 35 (0.01%)

COCKROACHDB SHARD DISTRIBUTION:
--------------------------------------------------
Shard 0: 186597 operations (33.3%)
Shard 1: 187480 operations (33.5%)
Shard 2: 185583 operations (33.2%)
Connection Errors: 0
Total Operations: 559660

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 49.91ms avg, 120000 calls
GETUSERPROFILE       | 7.96ms avg, 100000 calls
SAVETEAM             | 68.94ms avg, 99965 calls
GETUSERTEAMS         | 29.9ms avg, 99965 calls
TRANSFERTEAM         | 27.93ms avg, 9800 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       120000   49.91    12       4        944      292      495
getUserProfile  100000   7.96     7        2        107      15       23
saveTeam        99965    68.94    64       35       329      107      148
getUserTeams    99965    29.9     28       7        172      47       65
transferTeam    9800     27.93    26       14       190      44       60

================================================================================
🎉 CockroachDB POC testing completed successfully with ALL APIs
✨ All business logic handled in Node.js layer for better maintainability
🔌 Disconnected from CockroachDB cluster