# syntax=docker/dockerfile:1

# ---- builder ----
FROM ruby:3.3 AS builder

WORKDIR /app

COPY web/Gemfile web/Gemfile.lock* ./
COPY web/vendor/cache/ vendor/cache/
RUN bundle config set --local without 'development test' && \
    bundle install --local --jobs 4

# ---- final ----
FROM ruby:3.3-slim

COPY infra/debs-debian/ /tmp/debs/
RUN dpkg --force-overwrite --force-depends -i /tmp/debs/*.deb 2>&1 || true && \
    dpkg --force-overwrite --force-depends -i /tmp/debs/*.deb 2>&1 || true && \
    rm -rf /tmp/debs

# Run as non-root
RUN groupadd --gid 1001 rails && \
    useradd --uid 1001 --gid rails --shell /bin/bash --create-home rails

WORKDIR /app

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY web/ .

RUN chown -R rails:rails /app

COPY infra/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER rails

EXPOSE 3000

ENTRYPOINT ["entrypoint.sh"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
