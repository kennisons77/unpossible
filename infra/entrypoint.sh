#!/bin/sh
set -e

bundle exec rails db:create db:migrate
bundle exec rake ledger:import ledger:seed

exec "$@"
