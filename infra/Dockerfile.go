# syntax=docker/dockerfile:1

# ---- builder ----
FROM golang:1.23-bookworm AS builder

WORKDIR /build

COPY go/go.mod go/go.sum ./
COPY go/vendor/ vendor/
COPY go/cmd/ cmd/

RUN CGO_ENABLED=0 GOFLAGS=-mod=vendor go build -o /out/runner ./cmd/runner && \
    CGO_ENABLED=0 GOFLAGS=-mod=vendor go build -o /out/analytics ./cmd/analytics && \
    CGO_ENABLED=0 GOFLAGS=-mod=vendor go build -o /out/reference-parser ./cmd/reference-parser && \
    CGO_ENABLED=0 GOFLAGS=-mod=vendor go build -o /out/repo-map ./cmd/repo-map

# ---- runner ----
FROM debian:bookworm-slim AS runner

RUN useradd --uid 1001 --create-home runner

COPY --from=builder /out/runner /usr/local/bin/runner

USER runner

EXPOSE 8080

ENTRYPOINT ["runner"]

# ---- analytics ----
FROM debian:bookworm-slim AS analytics

RUN useradd --uid 1001 --create-home analytics

COPY --from=builder /out/analytics /usr/local/bin/analytics

USER analytics

EXPOSE 9100

ENTRYPOINT ["analytics"]
