# The Sovereign Library — Rails 8 + PostgreSQL + OCR tooling
FROM ruby:3.3-slim

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG PROXY_CA_CERT_B64

# Install proxy CA cert if provided
RUN if [ -n "$PROXY_CA_CERT_B64" ]; then \
      echo "$PROXY_CA_CERT_B64" | base64 -d > /usr/local/share/ca-certificates/proxy-ca.crt && \
      update-ca-certificates; \
    fi

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libyaml-dev \
      tesseract-ocr \
      tesseract-ocr-eng \
      poppler-utils \
      git \
      curl \
      libvips \
      pkg-config \
      nodejs \
      npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems first (cached layer)
COPY src/Gemfile src/Gemfile.lock* ./
RUN bundle lock --add-platform ruby && bundle install

# Install npm packages (cached layer)
COPY src/package.json ./
RUN npm install

# Copy app code — but preserve the generated Gemfile.lock
COPY src/ .
RUN bundle lock --add-platform ruby

# Build CSS and JS assets
RUN mkdir -p app/assets/builds && npm run build

EXPOSE 3000

CMD ["bin/rails", "server", "-b", "0.0.0.0"]
