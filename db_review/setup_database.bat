@echo off
set PSQL_EXE="C:\Program Files\PostgreSQL\16\bin\psql.exe"

REM Load environment variables from .env file if it exists
if exist .env (
  echo Loading environment variables from .env file...
  for /f "usebackq delims=" %%L in (`findstr /v "^#" .env`) do (
    for /f "tokens=1,* delims==" %%i in ("%%L") do set "%%i=%%j"
  )
  echo Finished loading .env file.
)

REM Display variables after loading for verification
echo.
echo --- Verifying loaded variables ---
echo PORT = [%PORT%]
echo ADMIN_PORT = [%ADMIN_PORT%]
echo USERNAME = [%USERNAME%]
echo ADMIN_DB = [%ADMIN_DB%]
echo USER_DATABASES = [%USER_DATABASES%]
echo PUBLICATION_NAME_PREFIX = [%PUBLICATION_NAME_PREFIX%]
echo PGPASSWORD = [%PGPASSWORD%]
echo ---------------------------------
echo.

pause

REM Continue with rest of script
REM This script runs all the setup SQL files in sequence for multiple databases.
REM It assumes the following environment variables are set:
REM - PORT: PostgreSQL port (e.g., 9999)
REM - USERNAME: PostgreSQL username (e.g., fantasy_agent)
REM - ADMIN_DB: The name of the admin database shard.
REM - USER_DATABASES: Comma-separated list of user database shards (e.g., user1,user2)
REM - PUBLICATION_NAME_PREFIX: A common prefix for pub/sub names (e.g., isl_fantasy_football)
REM - PGPASSWORD: PostgreSQL password

REM List of COMMON SQL files in execution order
set COMMON_FILES=01_create_schemas.sql 02_log_tables.sql 03_log_functions.sql 04_engine_config_sequences.sql 05_engine_config_tables.sql 06_engine_config_master_data.sql 07_engine_config_functions.sql 08_game_management_sequences.sql 09_game_management_tables.sql 10_game_management_functions.sql 11_game_user_sequences.sql 12_game_user_tables.sql 13_game_user_functions.sql 14_gameplay_sequences.sql 15_gameplay_tables.sql 16_gameplay_functions.sql 17_point_calculation_tables.sql 18_point_calculation_master_data.sql 19_point_calculation_functions.sql 20_league_sequences.sql 21_league_tables.sql 22_league_master_data.sql 23_league_functions.sql

REM Check if required environment variables are set
if not defined PORT ( echo Error: Missing required environment variable PORT. & pause & exit /b 1 )
if not defined USERNAME ( echo Error: Missing required environment variable USERNAME. & pause & exit /b 1 )
if not defined ADMIN_DB ( echo Error: Missing required environment variable ADMIN_DB. & pause & exit /b 1 )
if not defined USER_DATABASES ( echo Error: Missing required environment variable USER_DATABASES. & pause & exit /b 1 )
if not defined PGPASSWORD ( echo Error: Missing required environment variable PGPASSWORD. & pause & exit /b 1 )
if not defined PUBLICATION_NAME_PREFIX ( echo Error: Missing required environment variable PUBLICATION_NAME_PREFIX. & pause & exit /b 1 )

if not defined ADMIN_PORT (
  set "ADMIN_PORT=%PORT%"
)

REM --- Schema and Function Setup ---
set DEFAULT_DB=postgres

REM Process ADMIN DB
set ADMIN=%ADMIN_DB%
echo --- Processing ADMIN database: %ADMIN% ---

REM Test PostgreSQL connection first
echo Testing PostgreSQL connection...
%PSQL_EXE% -h localhost -p %ADMIN_PORT% -U %USERNAME% -d %DEFAULT_DB% -c "SELECT 1;"
if errorlevel 1 (
  echo ERROR: The psql command failed.
  echo The error from psql is likely displayed above this message.
  echo Please check your PostgreSQL pg_hba.conf file or if the psql path is correct.
  echo Path used: %PSQL_EXE%
  pause
  exit /b 1
)
echo PostgreSQL connection successful.

%PSQL_EXE% -h localhost -p %ADMIN_PORT% -U %USERNAME% -d %DEFAULT_DB% -tAc "SELECT 1 FROM pg_database WHERE datname='%ADMIN%'" | find "1" > nul
if errorlevel 1 (
  echo Database %ADMIN% does not exist. Creating it...
  %PSQL_EXE% -h localhost -p %ADMIN_PORT% -U %USERNAME% -d %DEFAULT_DB% -c "CREATE DATABASE \"%ADMIN%\""
  if errorlevel 1 ( echo Error creating %ADMIN%. Aborting. & pause & exit /b 1 )
) else (
  echo Database %ADMIN% already exists.
)

for %%f in (%COMMON_FILES%) do (
  if exist %%f (
    echo Executing %%f on %ADMIN%...
    %PSQL_EXE% -h localhost -p %ADMIN_PORT% -U %USERNAME% -d "%ADMIN%" -v ON_ERROR_STOP=1 -f %%f
    if ERRORLEVEL 1 ( echo Error in %%f on %ADMIN%. Aborting. & pause & exit /b 1 )
  )
)

REM Process USER_DATABASES
setlocal enabledelayedexpansion
set DBS=%USER_DATABASES%
:loop_common
for /f "tokens=1* delims=," %%a in ("!DBS!") do (
  set db=%%a
  if not "!db!" == "" (
    echo --- Processing USER database: !db! ---
    %PSQL_EXE% -h localhost -p %PORT% -U %USERNAME% -d %DEFAULT_DB% -tAc "SELECT 1 FROM pg_database WHERE datname='!db!'" | find "1" > nul
    if errorlevel 1 (
      echo Database !db! does not exist. Creating it...
      %PSQL_EXE% -h localhost -p %PORT% -U %USERNAME% -d %DEFAULT_DB% -c "CREATE DATABASE \"!db!\""
      if errorlevel 1 ( echo Error creating !db!. Aborting. & pause & exit /b 1 )
    ) else (
      echo Database !db! already exists.
    )

    for %%f in (%COMMON_FILES%) do (
      if exist %%f (
        echo Executing %%f on !db!...
        %PSQL_EXE% -h localhost -p %PORT% -U %USERNAME% -d "!db!" -v ON_ERROR_STOP=1 -f %%f
        if ERRORLEVEL 1 ( echo Error in %%f on !db!. Aborting. & pause & exit /b 1 )
      )
    )
  )
  set DBS=%%b
  if defined DBS goto :loop_common
)
endlocal

REM --- Pub/Sub Setup ---
echo --- Setting up Pub/Sub Replication ---

REM 1. Create Publication on Admin DB
set PUB_NAME=%PUBLICATION_NAME_PREFIX%_pub
echo Creating publication '%PUB_NAME%' on admin database '%ADMIN%'...
%PSQL_EXE% -h localhost -p %ADMIN_PORT% -U %USERNAME% -d "%ADMIN%" -v ON_ERROR_STOP=1 -v pub_name="%PUB_NAME%" -f "24_create_publication.sql"
if ERRORLEVEL 1 ( echo Error creating publication on %ADMIN%. Aborting. & pause & exit /b 1 )

REM 2. Create Subscription on each User DB
set CONN_INFO=host=localhost port=%ADMIN_PORT% user=%USERNAME% password=%PGPASSWORD% dbname=%ADMIN%
setlocal enabledelayedexpansion
set DBS=%USER_DATABASES%
:loop_sub
for /f "tokens=1* delims=," %%a in ("!DBS!") do (
  set db=%%a
  if not "!db!" == "" (
    set SUB_NAME=!db!_sub
    echo Creating subscription '!SUB_NAME!' on user database '!db!'...
    %PSQL_EXE% -h localhost -p %PORT% -U %USERNAME% -d "!db!" -v ON_ERROR_STOP=1 -v sub_name="!SUB_NAME!" -v pub_name="%PUB_NAME%" -v conn_info="%CONN_INFO%" -f "25_create_subscription.sql"
    if ERRORLEVEL 1 ( echo Error creating subscription on !db!. Aborting. & pause & exit /b 1 )
  )
  set DBS=%%b
  if defined DBS goto :loop_sub
)
endlocal

echo All scripts and pub/sub configurations executed successfully.
pause 