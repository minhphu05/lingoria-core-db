SHELL := /usr/bin/env bash

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PATH := /usr/local/bin:/opt/homebrew/bin:$(PATH)

.PHONY: help init-config check \
	pg-provision pg-init pg-list-db pg-list-users pg-status pg-performance pg-storage \
	pg-psql pg-psql-admin pg-backup pg-reset \
	minio-provision minio-list-buckets minio-list-users minio-status \
	redis-provision redis-list-keys redis-list-users redis-status redis-performance redis-storage redis-flush

help:
	@echo "=================================================================="
	@echo "       Lingoria Core Database & Storage Operations (DataOps)"
	@echo "=================================================================="
	@echo "Initialization & Configuration:"
	@echo "  make init-config             Create .env from .env.example"
	@echo ""
	@echo "PostgreSQL DBA Management:"
	@echo "  make pg-provision            Provision DBs, users & extensions from configs/postgres.json"
	@echo "  make pg-init                 One-time initialization of 'lingoria' core DB (schemas + seed)"
	@echo "  make pg-list-db              List all PostgreSQL databases and sizes"
	@echo "  make pg-list-users           List all PostgreSQL users/roles and privileges"
	@echo "  make pg-status               Check PostgreSQL health, connections & uptime"
	@echo "  make pg-performance          Check cache hit ratio, blocking locks & slow queries"
	@echo "  make pg-storage              Analyze table and index disk space utilization"
	@echo "  make pg-psql                 Open interactive psql with app user ('lingoria')"
	@echo "  make pg-psql-admin           Open interactive psql with Superuser ('postgres')"
	@echo "  make pg-backup               Export schema and data backup to backups/"
	@echo "  make pg-reset CONFIRM=YES    Drop schemas and re-run pg-init"
	@echo ""
	@echo "MinIO Storage Management:"
	@echo "  make minio-provision         Provision buckets, policies & users from configs/minio.json"
	@echo "  make minio-list-buckets      List all buckets, creation dates & disk usage"
	@echo "  make minio-list-users        List MinIO users and service accounts"
	@echo "  make minio-status            Check MinIO health, uptime & server info"
	@echo ""
	@echo "Redis Cache Operations:"
	@echo "  make redis-provision         Provision ACL users & validate namespaces from configs/redis.json"
	@echo "  make redis-list-keys         Count keys by namespace & sample active keys"
	@echo "  make redis-list-users        List Redis ACL users and rules"
	@echo "  make redis-status            Check Redis ping, uptime & connected clients"
	@echo "  make redis-performance       Measure hit ratio & operations per second"
	@echo "  make redis-storage           Inspect memory consumption breakdown"
	@echo "  make redis-flush CONFIRM=YES Flush all keys in Redis cache"
	@echo "=================================================================="

init-config:
	@test -f .env || cp .env.example .env
	@echo "Configuration ready: $(ROOT_DIR)/.env"

check:
	@command -v psql >/dev/null || { echo "psql is required. Install PostgreSQL client tools." >&2; exit 1; }
	@test -f .env || cp .env.example .env

# ==============================================================================
# 1. PostgreSQL Targets
# ==============================================================================
pg-provision: check
	@./scripts/postgres/provision.sh

pg-init: check
	@./scripts/postgres/init-db.sh

pg-list-db: check
	@./scripts/postgres/list-db.sh

pg-list-users: check
	@./scripts/postgres/list-users.sh

pg-status: check
	@./scripts/postgres/status.sh

pg-performance: check
	@./scripts/postgres/performance.sh

pg-storage: check
	@./scripts/postgres/storage.sh

pg-psql: check
	@./scripts/postgres/psql.sh

pg-psql-admin: check
	@./scripts/postgres/psql.sh --admin postgres

pg-backup: check
	@./scripts/postgres/backup.sh

pg-reset: check
	@test "$(CONFIRM)" = "YES" || { echo "Refusing to reset database. Re-run with CONFIRM=YES" >&2; exit 1; }
	@./scripts/postgres/psql.sh -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS platform, catalog, content, learning, linguistic, media, assessment, culture, progress, community, notification, billing, ingestion, search, analytics CASCADE;"
	@$(MAKE) pg-init

# ==============================================================================
# 2. MinIO Targets
# ==============================================================================
minio-provision: check
	@./scripts/minio/provision.sh

minio-list-buckets: check
	@./scripts/minio/list-buckets.sh

minio-list-users: check
	@./scripts/minio/list-users.sh

minio-status: check
	@./scripts/minio/status.sh

# ==============================================================================
# 3. Redis Targets
# ==============================================================================
redis-provision: check
	@./scripts/redis/provision.sh

redis-list-keys: check
	@./scripts/redis/list-keys.sh

redis-list-users: check
	@./scripts/redis/list-users.sh

redis-status: check
	@./scripts/redis/status.sh

redis-performance: check
	@./scripts/redis/performance.sh

redis-storage: check
	@./scripts/redis/storage.sh

redis-flush: check
	@CONFIRM="$(CONFIRM)" ./scripts/redis/flush.sh
