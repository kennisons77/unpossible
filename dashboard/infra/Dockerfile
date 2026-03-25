# syntax=docker/dockerfile:1

# ── build ──────────────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY src/ .
RUN go mod download && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags='-s -w' -o /dashboard ./cmd/server

# ── runtime ────────────────────────────────────────────────────────────────
FROM alpine:3.19
RUN adduser -D -u 1000 app
COPY --from=builder /dashboard /usr/local/bin/dashboard
USER app
EXPOSE 8080
ENTRYPOINT ["dashboard"]
