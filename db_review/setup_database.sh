#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "Loading environment variables from .env file..."
  set -a
  source .env
  set +a
fi

# This script runs all the setup SQL files in sequence for multiple databases.
# It assumes the following environment variables are set:
# - PORT: PostgreSQL port (e.g., 9999)
# - USERNAME: PostgreSQL username (e.g., fantasy_agent)
# - ADMIN_DB: The name of the admin database shard.
# - USER_DATABASES: Comma-separated list of user database shards (e.g., user1,user2)
# - PUBLICATION_NAME_PREFIX: A common prefix for pub/sub names (e.g., isl_fantasy_football)
# - PGPASSWORD: PostgreSQL password

# List of COMMON SQL files in execution order
COMMON_FILES=(
  "01_create_schemas.sql"
  "02_log_tables.sql"
  "03_log_functions.sql"
  "04_engine_config_sequences.sql"
  "05_engine_config_tables.sql"
  "06_engine_config_master_data.sql"
  "07_engine_config_functions.sql"
  "08_game_management_sequences.sql"
  "09_game_management_tables.sql"
  "10_game_management_functions.sql"
  "11_game_user_sequences.sql"
  "12_game_user_tables.sql"
  "13_game_user_functions.sql"
  "14_gameplay_sequences.sql"
  "15_gameplay_tables.sql"
  "16_gameplay_functions.sql"
  "17_point_calculation_tables.sql"
  "18_point_calculation_master_data.sql"
  "19_point_calculation_functions.sql"
  "20_league_sequences.sql"
  "21_league_tables.sql"
  "22_league_master_data.sql"
  "23_league_functions.sql"
)

# Check if required environment variables are set
if [ -z "$PORT" ] || [ -z "$USERNAME" ] || [ -z "$ADMIN_DB" ] || [ -z "$USER_DATABASES" ] || [ -z "$PGPASSWORD" ] || [ -z "$PUBLICATION_NAME_PREFIX" ]; then
  echo "Error: Missing required environment variables (PORT, USERNAME, ADMIN_DB, USER_DATABASES, PUBLICATION_NAME_PREFIX, PGPASSWORD)."
  exit 1
fi

export PGPASSWORD

# Assume a default database for admin operations
DEFAULT_DB="postgres"

# --- Schema and Function Setup ---

# Process ADMIN database
ADMIN="$ADMIN_DB"
echo "--- Processing ADMIN database: $ADMIN ---"
DB_EXISTS=$(psql -h localhost -p $PORT -U $USERNAME -d $DEFAULT_DB -tAc "SELECT 1 FROM pg_database WHERE datname='$ADMIN'")
if [ -z "$DB_EXISTS" ]; then
  echo "Database $ADMIN does not exist. Creating it..."
  psql -h localhost -p $PORT -U $USERNAME -d $DEFAULT_DB -c "CREATE DATABASE \"$ADMIN\"" || { echo "Error creating $ADMIN"; exit 1; }
else
  echo "Database $ADMIN already exists."
fi
for file in "${COMMON_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "Executing $file on $ADMIN..."
    psql -h localhost -p $PORT -U $USERNAME -d "$ADMIN" -f "$file"
    if [ $? -ne 0 ]; then echo "Error executing $file on $ADMIN. Aborting."; exit 1; fi
  else
    echo "File $file not found. Skipping."
  fi
done

# Process USER_DATABASES
IFS=',' read -r -a USER_ARRAY <<< "$USER_DATABASES"
for USER_DB in "${USER_ARRAY[@]}"; do
  echo "--- Processing USER database: $USER_DB ---"
  DB_EXISTS=$(psql -h localhost -p $PORT -U $USERNAME -d $DEFAULT_DB -tAc "SELECT 1 FROM pg_database WHERE datname='$USER_DB'")
  if [ -z "$DB_EXISTS" ]; then
    echo "Database $USER_DB does not exist. Creating it..."
    psql -h localhost -p $PORT -U $USERNAME -d $DEFAULT_DB -c "CREATE DATABASE \"$USER_DB\"" || { echo "Error creating $USER_DB"; exit 1; }
  else
    echo "Database $USER_DB already exists."
  fi
  for file in "${COMMON_FILES[@]}"; do
    if [ -f "$file" ]; then
      echo "Executing $file on $USER_DB..."
      psql -h localhost -p $PORT -U $USERNAME -d "$USER_DB" -f "$file"
      if [ $? -ne 0 ]; then echo "Error executing $file on $USER_DB. Aborting."; exit 1; fi
    else
      echo "File $file not found. Skipping."
    fi
  done
done

# --- Pub/Sub Setup ---
echo "--- Setting up Pub/Sub Replication ---"

# 1. Create Publication on Admin DB
PUB_NAME="${PUBLICATION_NAME_PREFIX}_pub"
echo "Creating publication '$PUB_NAME' on admin database '$ADMIN'..."
psql -h localhost -p $PORT -U $USERNAME -d "$ADMIN" -v pub_name="$PUB_NAME" -f "24_create_publication.sql"
if [ $? -ne 0 ]; then echo "Error creating publication on $ADMIN. Aborting."; exit 1; fi

# 2. Create Subscription on each User DB
CONN_INFO="host=localhost port=$PORT user=$USERNAME password=$PGPASSWORD dbname=$ADMIN"
for USER_DB in "${USER_ARRAY[@]}"; do
  SUB_NAME="${USER_DB}_sub"
  echo "Creating subscription '$SUB_NAME' on user database '$USER_DB'..."
  psql -h localhost -p $PORT -U $USERNAME -d "$USER_DB" -v sub_name="$SUB_NAME" -v pub_name="$PUB_NAME" -v "conn_info='$CONN_INFO'" -f "25_create_subscription.sql"
  if [ $? -ne 0 ]; then echo "Error creating subscription on $USER_DB. Aborting."; exit 1; fi
done

echo "All scripts and pub/sub configurations executed successfully."

unset PGPASSWORD 