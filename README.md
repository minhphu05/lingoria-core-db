# Lingoria Core Data Tier (DBA & DataOps)

Repository quản lý cấu trúc cơ sở dữ liệu và hạ tầng lưu trữ lõi của nền tảng Lingoria, bao gồm **PostgreSQL** (14 schemas nghiệp vụ & pgvector), **MinIO** (Object Storage) và **Redis** (In-Memory Cache).

Repository này hoạt động **hoàn toàn độc lập** với repository triển khai hạ tầng container [lingoria-platform-deployment](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment).

---

## 1. Cấu Trúc Repository

```text
lingoria-core-db/
├── .env.example                  # Mẫu cấu hình kết nối Postgres (Superuser + App), MinIO, Redis
├── .env                          # File cấu hình kết nối thực tế trên máy local (gitignored)
├── Makefile                      # Giao diện dòng lệnh tập trung (make pg-*, minio-*, redis-*, dba-*)
├── README.md                     # Tài liệu tổng quan
│
├── sql/                          # Toàn bộ SQL logic (thuần SQL, mở và chạy trực tiếp trên DBeaver)
│   ├── init/                     # Khởi tạo cấp hệ thống (yêu cầu quyền Superuser 'postgres')
│   │   ├── 001_create_databases.sql  # Tạo database 'lingoria' và 'airflow'
│   │   ├── 002_create_roles.sql      # Tạo app user 'lingoria' và cấp quyền truy cập
│   │   └── 003_extensions.sql        # Kích hoạt pgvector, pgcrypto, citext, pg_trgm
│   ├── migrations/               # DDL schemas nghiệp vụ theo phiên bản (0001 - 0010...)
│   ├── seeds/                    # Dữ liệu tĩnh tham chiếu ban đầu (Catalog data)
│   └── dba/                      # Script chẩn đoán hiệu năng, kích thước bảng và locks
│
├── scripts/                      # Bộ script tự động hoá và vận hành
│   ├── dba-check.sh              # Kiểm tra kết nối đồng thời Postgres, MinIO và Redis
│   ├── postgres/                 # Scripts quản trị PostgreSQL (init, migrate, seed, psql, backup)
│   ├── minio/                    # Scripts quản trị MinIO (init-buckets, status)
│   └── redis/                    # Scripts quản trị Redis (ping, stats, flush)
│
└── docs/                         # Tài liệu chuyên sâu cho Data Engineers & DBA
    ├── architecture.md           # Thiết kế 14 schemas và ranh giới nghiệp vụ của Lingoria
    ├── dbeaver_guide.md          # Hướng dẫn kết nối và chạy SQL bằng DBeaver
    └── operations_runbook.md     # Sổ tay vận hành DBA (bootstrap, migrations, backup & restore)
```

---

## 2. Hướng Dẫn Nhanh (Quick Start)

### Bước 1: Khởi tạo file môi trường & cấu hình kết nối
```bash
make init-config
# Cập nhật PG_SUPERUSER_PASSWORD và MINIO_ROOT_PASSWORD lấy từ `make show-credentials` của deployment repo
```

### Bước 2: Khởi tạo Database, User & Extensions (Superuser)
```bash
make pg-init
# Hoặc mở sql/init/*.sql chạy bằng DBeaver (Profile Superuser)
```

### Bước 3: Áp dụng Migrations & Nạp Seed Data
```bash
make pg-migrate
make pg-seed
make pg-status
```

### Bước 4: Khởi tạo MinIO Buckets & Kiểm tra toàn diện
```bash
make minio-init
make dba-check
```

---

## 3. Danh Mục Lệnh Thao Tác (Makefile Reference)

```bash
# Khởi tạo & Kiểm tra
make init-config              # Tạo .env từ .env.example
make dba-check                # Kiểm tra kết nối tới Postgres, MinIO và Redis
make dba-report               # Báo cáo dung lượng bảng và trạng thái khóa (locks)

# Quản trị PostgreSQL
make pg-init                  # Tạo database 'lingoria', user và extensions bằng Superuser
make pg-migrate               # Áp dụng các migrations mới
make pg-seed                  # Nạp dữ liệu seed catalog
make pg-status                # Xem danh sách migrations đã chạy
make pg-psql                  # Mở interactive psql shell với user 'lingoria'
make pg-psql-admin            # Mở psql shell với Superuser 'postgres'
make pg-backup                # Sao lưu schema & data vào backups/
make pg-reset CONFIRM=YES     # Xoá toàn bộ schemas và chạy lại migrations từ đầu

# Quản trị MinIO
make minio-init               # Tạo 4 buckets (raw, media, local) và set public policy
make minio-status             # Xem danh sách và dung lượng các bucket

# Quản trị Redis
make redis-ping               # Kiểm tra kết nối Redis
make redis-stats              # Xem thông số bộ nhớ và keyspace
make redis-flush CONFIRM=YES  # Xoá toàn bộ cache Redis
```

---

## 4. Tài Liệu Chi Tiết Trong `docs/`

- **[docs/architecture.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/docs/architecture.md)**: Chi tiết 14 PostgreSQL schemas và chiến lược lưu trữ dữ liệu.
- **[docs/dbeaver_guide.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/docs/dbeaver_guide.md)**: Hướng dẫn cấu hình DBeaver và thực thi các file SQL.
- **[docs/operations_runbook.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/docs/operations_runbook.md)**: Sổ tay vận hành DBA cho Data Engineers.
