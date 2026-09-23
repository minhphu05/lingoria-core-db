# Lingoria Core Data Tier (DBA & DataOps)

Repository quản lý cấu trúc cơ sở dữ liệu và hạ tầng lưu trữ lõi của nền tảng Lingoria, bao gồm **PostgreSQL** (14 schemas nghiệp vụ & pgvector), **MinIO** (Object Storage) và **Redis** (In-Memory Cache).

Repository này hoạt động **hoàn toàn độc lập** với repository triển khai hạ tầng container [lingoria-platform-deployment](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment).

---

## 1. Cấu Trúc Repository

```text
lingoria-core-db/
├── configs/                      # Cấu hình khai báo (Declarative Provisioning)
│   ├── postgres.json             # Danh sách DBs, Users, Quyền hạn, Extensions
│   ├── minio.json                # Danh sách Buckets, Policies, Users
│   └── redis.json                # Cấu hình ACL Users, Key Namespaces
├── .env.example                  # Mẫu cấu hình kết nối Postgres (Superuser + App), MinIO, Redis
├── .env                          # File cấu hình kết nối thực tế trên máy local (gitignored)
├── Makefile                      # Giao diện dòng lệnh tập trung (make pg-*, minio-*, redis-*)
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
│   ├── postgres/                 # Scripts quản trị PostgreSQL (provision, init-db, list, status, performance, storage)
│   ├── minio/                    # Scripts quản trị MinIO (provision, list-buckets, list-users, status)
│   └── redis/                    # Scripts quản trị Redis (provision, list-keys, list-users, status, performance, storage, flush)
│
└── docs/                         # Tài liệu chuyên sâu cho Data Engineers & DBA
    ├── architecture.md           # Thiết kế 14 schemas và ranh giới nghiệp vụ của Lingoria
    ├── dbeaver_guide.md          # Hướng dẫn kết nối và chạy SQL bằng DBeaver
    └── operations_runbook.md     # Sổ tay vận hành DBA (bootstrap, provision, backup & restore)
```

---

## 2. Hướng Dẫn Nhanh (Quick Start)

### Bước 1: Khởi tạo file môi trường & cấu hình kết nối
```bash
make init-config
# Cập nhật PG_SUPERUSER_PASSWORD và MINIO_ROOT_PASSWORD lấy từ `make show-credentials` của deployment repo
```

### Bước 2: Declarative Provisioning (Cấp Superuser)
Khởi tạo tự động Databases, Users, Phân quyền và Buckets theo `configs/*.json`:
```bash
make pg-provision
make minio-provision
make redis-provision
```
*(Các lệnh này hoàn toàn Idempotent, có thể chạy lại nhiều lần an toàn)*

### Bước 3: Khởi tạo One-Time Core Database `lingoria`
```bash
make pg-init
```
*(Chỉ chạy 1 lần duy nhất cho core DB. Nếu DB đã được khởi tạo, lệnh sẽ tự động bảo vệ dữ liệu và bỏ qua)*

---

## 3. Danh Mục Lệnh Thao Tác (Makefile Reference)

### Nhóm PostgreSQL:
```bash
make pg-provision            # Khởi tạo DBs, users & extensions từ configs/postgres.json
make pg-init                 # Khởi tạo 1 lần duy nhất cho core DB 'lingoria' (schemas + seed)
make pg-list-db              # Liệt kê tất cả databases và dung lượng
make pg-list-users           # Liệt kê tất cả users/roles và quyền hạn
make pg-status               # Kiểm tra kết nối, uptime và số lượng active connections
make pg-performance          # Đo cache hit ratio, locks và slow queries
make pg-storage              # Phân tích dung lượng đĩa của từng bảng và index
make pg-psql                 # Mở interactive psql shell với app user ('lingoria')
make pg-psql-admin           # Mở interactive psql shell với Superuser ('postgres')
make pg-backup               # Sao lưu database ra thư mục backups/
make pg-reset CONFIRM=YES    # Xoá schemas và khởi tạo lại từ đầu
```

### Nhóm MinIO:
```bash
make minio-provision         # Tạo buckets, policies & users từ configs/minio.json
make minio-list-buckets      # Liệt kê danh sách buckets và dung lượng
make minio-list-users        # Liệt kê users và service accounts
make minio-status            # Kiểm tra trạng thái server, uptime & dung lượng tổng
```

### Nhóm Redis:
```bash
make redis-provision         # Khởi tạo ACL users và namespaces từ configs/redis.json
make redis-list-keys         # Đếm số lượng key theo từng namespace
make redis-list-users        # Liệt kê danh sách ACL users
make redis-status            # Kiểm tra ping, uptime & connected clients
make redis-performance       # Đo lường tỷ lệ hit ratio & ops/giây
make redis-storage           # Phân tích chi tiết bộ nhớ RAM sử dụng
make redis-flush CONFIRM=YES # Xoá sạch toàn bộ keys trong cache
```

---

## 4. Tài Liệu Chi Tiết Trong `docs/`

- **[docs/architecture.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/docs/architecture.md)**: Chi tiết 14 PostgreSQL schemas và chiến lược lưu trữ dữ liệu.
- **[docs/dbeaver_guide.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/docs/dbeaver_guide.md)**: Hướng dẫn cấu hình DBeaver và thực thi các file SQL.
- **[docs/operations_runbook.md](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/docs/operations_runbook.md)**: Sổ tay vận hành DBA cho Data Engineers.
