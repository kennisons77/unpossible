#!/bin/bash
set -e

# Wait for postgres to be ready, then create DB and run migrations
bundle exec rails db:create db:migrate 2>/dev/null || bundle exec rails db:migrate

exec "$@"
