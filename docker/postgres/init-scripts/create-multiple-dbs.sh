#!/bin/bash
set -euo pipefail

function create_db_and_user_if_not_exists() {
  local dbName="$1"
  local dbUser="$2"
  local dbPass="$3"

  echo "Ensuring database '$dbName' and user '$dbUser' exist..."

  # Create user if not exists
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- Create user if not exists
    DO \$\$
    BEGIN
      IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles 
        WHERE rolname = '$dbUser'
      ) THEN
        CREATE ROLE $dbUser LOGIN PASSWORD '$dbPass';
      END IF;
    END
    \$\$;
EOSQL

  # Check if database exists and create it if not
  db_exists=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='$dbName'")
  if [ -z "$db_exists" ]; then
    echo "Creating database $dbName..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE $dbName OWNER $dbUser"
  else
    echo "Database $dbName already exists."
  fi
}

# If POSTGRES_MULTIPLE_DBS is non-empty, parse it
if [[ -n "${POSTGRES_MULTIPLE_DBS:-}" ]]; then
  echo "Multiple DB creation requested"

  # Split on comma, e.g. "db1:user1:pass1,db2:user2:pass2"
  IFS=',' read -ra DB_ARRAY <<<"$POSTGRES_MULTIPLE_DBS"

  for entry in "${DB_ARRAY[@]}"; do
    # Each entry is "db:user:pass"
    IFS=':' read -ra DB_INFO <<<"$entry"
    dbName="${DB_INFO[0]}"
    dbUser="${DB_INFO[1]}"
    dbPass="${DB_INFO[2]}"

    create_db_and_user_if_not_exists "$dbName" "$dbUser" "$dbPass"
  done

  echo "All requested databases/users created (if they didn't already exist)."
else
  echo "No extra databases to create. POSTGRES_MULTIPLE_DBS is empty."
fi
