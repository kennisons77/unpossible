# syntax=docker/dockerfile:1

# ---- builder ----
FROM ruby:3.3-slim AS builder

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      libyaml-dev \
      git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/Gemfile app/Gemfile.lock* ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# ---- final ----
FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      libpq5 \
      curl \
    && rm -rf /var/lib/apt/lists/*

# Run as non-root
RUN groupadd --gid 1001 rails && \
    useradd --uid 1001 --gid rails --shell /bin/bash --create-home rails

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY app/ .

RUN chown -R rails:rails /app

USER rails

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
