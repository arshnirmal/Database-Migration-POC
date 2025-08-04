================================================================================
FANTASY GAME CASSANDRA POC - PERFORMANCE REPORT
================================================================================
Generated: 2025-07-30T09:19:59.531834
Total Errors: 0 (0.00%)

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USER_LOGIN           | 27.23ms avg, 100 calls
USER_PROFILE         | 14.81ms avg, 100 calls
SAVE_TEAM            | 9.41ms avg, 2022 calls
TEAM_TRANSFER        | 22.07ms avg, 27 calls
GET_USER_TEAMS       | 15.36ms avg, 100 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)    Med(ms)    Min(ms)    Max(ms)    P95(ms)    P99(ms)   
--------------------------------------------------------------------------------
user_login      100      27.23      25.08      18.72      46.72      41.13      N/A       
user_profile    100      14.81      13.39      7.25       31.51      23.85      N/A       
save_team       2022     9.41       8.87       5.12       63.92      13.55      18.05     
team_transfer   27       22.07      22.93      10.19      30.6       30.42      N/A       
get_user_teams  100      15.36      14.18      7.47       29.77      25.08      N/A       

================================================================================

➜  nosql node poc-test/fantasy-game-poc.js                    
🎮 Starting Fantasy Game Cassandra POC (Node.js)
📊 Configuration: 1000 users, 100 tests
✅ Connected to Cassandra cluster
✅ Prepared statements created successfully
🔄 Generating test data for 1000 users...
📊 Created 50/1000 users (5%)
📊 Created 250/1000 users (25%)
📊 Created 450/1000 users (45%)
📊 Created 650/1000 users (65%)
📊 Created 850/1000 users (85%)
📊 Created 1000/1000 users (100%)
✅ Successfully created 1000 users with teams
⏱️  Starting performance tests...
🚀 Running 100 performance tests...
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
⚠️ Same gameset update not implemented - would update existing record
✅ Performance tests completed

================================================================================
FANTASY GAME CASSANDRA POC - PERFORMANCE REPORT
================================================================================
Generated: 2025-07-30T10:45:14.454Z
Total Errors: 0 (0.00%)

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 133.88ms avg, 100 calls
USERPROFILE          | 40.48ms avg, 100 calls
GETUSERTEAMS         | 54.08ms avg, 100 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)    Med(ms)    Min(ms)    Max(ms)    P95(ms)    P99(ms)
--------------------------------------------------------------------------------
userLogin       100      133.88     121        39         265        255        265       
userProfile     100      40.48      34         14         213        128        213       
getUserTeams    100      54.08      40         14         136        126        136       

================================================================================
🎉 POC testing completed successfully
🔌 Disconnected from Cassandra

Local Quorum = 1
  nosql node poc-test/fantasy-game-poc.js                        
🎮 Starting Fantasy Game Cassandra POC (Node.js)
📊 Configuration: 1000 users, 100 tests
✅ Connected to Cassandra cluster
✅ Prepared statements created successfully
🔄 Generating test data for 1000 users...
📊 Created 10/1000 users (1%)
📊 Created 210/1000 users (21%)
📊 Created 410/1000 users (41%)
📊 Created 610/1000 users (61%)
📊 Created 810/1000 users (81%)
📊 Created 1000/1000 users (100%)
✅ Successfully created 1000 users with teams
⏱️  Starting performance tests...
🚀 Running 100 performance tests...
✅ Performance tests completed

================================================================================
FANTASY GAME CASSANDRA POC - PERFORMANCE REPORT
================================================================================
Generated: 2025-07-30T11:14:34.181Z
Total Errors: 0 (0.00%)

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
SAVETEAM             | 15.09ms avg, 100 calls
GETUSERTEAMS         | 5.52ms avg, 100 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)    Med(ms)    Min(ms)    Max(ms)    P95(ms)    P99(ms)
--------------------------------------------------------------------------------
saveTeam        100      15.09      14         11         42         30         42        
getUserTeams    100      5.52       5          4          14         8          14        

================================================================================
🎉 POC testing completed successfully
🔌 Disconnected from Cassandra

Local Quoram = 2
================================================================================
FANTASY GAME CASSANDRA POC - PERFORMANCE REPORT
================================================================================
Generated: 2025-07-30T12:34:56.511Z
Total Errors: 0 (0.00%)

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
SAVETEAM             | 19.35ms avg, 100000 calls
GETUSERTEAMS         | 10.12ms avg, 100000 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation       Calls    Avg(ms)    Med(ms)    Min(ms)    Max(ms)    P95(ms)    P99(ms)
--------------------------------------------------------------------------------
saveTeam        100000   19.35      16         9          277        33         62        
getUserTeams    100000   10.12      8          3          180        23         37        

================================================================================
🎉 POC testing completed successfully
🔌 Disconnected from Cassandra

➜  poc-test node fantasy-game-poc.js --users 5 --tests 20 --skip-data
🎮 Starting Fantasy Game Cassandra POC (Node.js)
📊 Configuration: 5 users, 20 tests
✅ Connected to Cassandra cluster
✅ Prepared statements created successfully
📊 Generating user data structures for 5 users (no database inserts)...
✅ Generated 5 user data structures
⏱️ Starting performance tests...
🚀 Running 20 performance tests...
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
⚠️ Transfer validation failed: INVALID_FORMATION
✅ Performance tests completed

================================================================================
FANTASY GAME CASSANDRA POC - PERFORMANCE REPORT
================================================================================
Generated: 2025-07-31T07:40:32.529Z
Total Errors: 20 (19.42%)
Transfer Validation Errors: 9

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 43.15ms avg, 20 calls
GETUSERPROFILE       | 13.71ms avg, 14 calls
SAVETEAM             | 55.3ms avg, 20 calls
GETUSERTEAMS         | 22.5ms avg, 20 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation        Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       20       43.15    27       24       121      121      121     
getUserProfile  14       13.71    14       12       16       16       16      
saveTeam        20       55.3     44       35       121      121      121     
getUserTeams    20       22.5     18       14       45       45       45      

================================================================================
🎉 POC testing completed successfully
🔌 Disconnected from Cassandra


================================================================================
FANTASY GAME CASSANDRA POC - ENHANCED PERFORMANCE REPORT
================================================================================
Generated: 2025-07-31T08:58:52.699Z
Total Errors: 0 (0.00%)
Transfer Validation Errors: 0
Memory Usage: 57MB heap

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 13.23ms avg, 72578 calls
GETUSERPROFILE       | 6.79ms avg, 126523 calls
SAVETEAM             | 19.7ms avg, 74585 calls
GETUSERTEAMS         | 7.31ms avg, 71985 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation        Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       72578    13.23    12.08    4.27     217.5    21.37    34.54   
getUserProfile  126523   6.79     6.14     1.21     209.55   11.4     17.96   
saveTeam        74585    19.7     18.17    5.92     233.17   30.85    48.99   
getUserTeams    71985    7.31     6.64     1.4      162.08   12.03    18.57   

================================================================================
🎉 Complete optimized POC testing completed successfully
🔌 Disconnected from Cassandra

================================================================================
FANTASY GAME CASSANDRA POC - ENHANCED PERFORMANCE REPORT
================================================================================
Generated: 2025-07-31T09:13:18.931Z
Total Errors: 0 (0.00%)
Transfer Validation Errors: 0
Memory Usage: 39MB heap

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 8.76ms avg, 70014 calls
GETUSERPROFILE       | 4.5ms avg, 120253 calls
SAVETEAM             | 13.02ms avg, 73847 calls
GETUSERTEAMS         | 4.86ms avg, 70842 calls
TRANSFERTEAM         | 13.7ms avg, 9925 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation        Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       70014    8.76     7.91     2.61     171.65   14.36    22.65   
getUserProfile  120253   4.5      4.05     0.66     162.34   7.63     12.07   
saveTeam        73847    13.02    11.91    4.79     175.72   20.71    32.69   
getUserTeams    70842    4.86     4.42     0.92     162      7.95     12.47   
transferTeam    9925     13.7     12.55    6.17     177.07   21.57    33.51   

================================================================================
🎉 Complete optimized POC testing completed successfully
🔌 Disconnected from Cassandra

================================================================================
FANTASY GAME CASSANDRA POC - ENHANCED PERFORMANCE REPORT
================================================================================
Generated: 2025-08-04T21:36:00.672Z
Total Errors: 0 (0.00%)
Transfer Validation Errors: 0
Memory Usage: 69MB heap

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 8.37ms avg, 69897 calls
GETUSERPROFILE       | 4.3ms avg, 121056 calls
SAVETEAM             | 12.48ms avg, 74135 calls
GETUSERTEAMS         | 4.63ms avg, 70398 calls
TRANSFERTEAM         | 13.16ms avg, 9942 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation        Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       69897    8.37     7.71     2.54     223.76   12.88    20.97   
getUserProfile  121056   4.3      3.96     0.91     93.61    6.86     10.94   
saveTeam        74135    12.48    11.66    4.99     125.93   18.34    29.64   
getUserTeams    70398    4.63     4.3      1.13     98.12    7.11     10.82   
transferTeam    9942     13.16    12.32    6.01     154.72   18.95    29.67   

================================================================================
🎉 Complete optimized POC testing completed successfully
🔌 Disconnected from Cassandra

Windows
================================================================================
FANTASY GAME CASSANDRA POC - ENHANCED PERFORMANCE REPORT
================================================================================
Generated: 2025-08-04T17:26:20.312Z
Total Errors: 0 (0.00%)
Transfer Validation Errors: 0
Memory Usage: 31MB heap

OPERATION PERFORMANCE SUMMARY:
--------------------------------------------------
USERLOGIN            | 10.54ms avg, 71005 calls
GETUSERPROFILE       | 5.4ms avg, 120420 calls
SAVETEAM             | 15.83ms avg, 75249 calls
GETUSERTEAMS         | 5.78ms avg, 73276 calls
TRANSFERTEAM         | 16.65ms avg, 9939 calls

DETAILED STATISTICS:
--------------------------------------------------------------------------------
Operation        Calls    Avg(ms)  Med(ms)  Min(ms)  Max(ms)  P95(ms)  P99(ms)
--------------------------------------------------------------------------------
userLogin       71005    10.54    9.12     3.55     191.05   18.66    30.97
getUserProfile  120420   5.4      4.62     1.13     177.39   10.07    16.71
saveTeam        75249    15.83    13.9     6.52     194.04   26.93    43.84
getUserTeams    73276    5.78     4.98     1.64     177.56   10.7     17.54
transferTeam    9939     16.65    14.66    7.43     174.23   28.41    42.28

================================================================================
🎉 Complete optimized POC testing completed successfully
🔌 Disconnected from Cassandra