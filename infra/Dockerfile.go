# syntax=docker/dockerfile:1

# ---- builder ----
FROM golang:1.22-bookworm AS builder

WORKDIR /src

COPY go/go.mod go/go.sum ./
COPY go/vendor/ vendor/
COPY go/ .

RUN CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /out/runner ./cmd/runner && \
    CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /out/analytics ./cmd/analytics && \
    CGO_ENABLED=0 GOOS=linux go build -mod=vendor -o /out/parser ./cmd/parser

# ---- runner ----
FROM debian:bookworm-slim AS runner

RUN groupadd --gid 1001 app && useradd --uid 1001 --gid app --no-create-home app
COPY --from=builder /out/runner /usr/local/bin/runner
USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/runner"]

# ---- analytics ----
FROM debian:bookworm-slim AS analytics

RUN groupadd --gid 1001 app && useradd --uid 1001 --gid app --no-create-home app
COPY --from=builder /out/analytics /usr/local/bin/analytics
USER app
EXPOSE 9100
ENTRYPOINT ["/usr/local/bin/analytics"]

# ---- parser ----
FROM debian:bookworm-slim AS parser

RUN groupadd --gid 1001 app && useradd --uid 1001 --gid app --no-create-home app
COPY --from=builder /out/parser /usr/local/bin/parser
USER app
ENTRYPOINT ["/usr/local/bin/parser"]
