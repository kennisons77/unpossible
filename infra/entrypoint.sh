#!/bin/sh
set -e

bundle exec rails db:create db:migrate db:seed
bundle exec rake ledger:import ledger:seed

exec "$@"
