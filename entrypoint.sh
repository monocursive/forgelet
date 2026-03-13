#!/bin/bash
set -e

# Wait for PostgreSQL to accept TCP connections
until bash -c "echo > /dev/tcp/${DB_HOST:-localhost}/5432" 2>/dev/null; do
  echo "Waiting for PostgreSQL at ${DB_HOST:-localhost}:5432..."
  sleep 2
done
echo "PostgreSQL is ready."

# Run full project setup (deps.get, ecto.setup, assets.setup, assets.build)
mix setup

# Start the Phoenix server
exec mix phx.server
