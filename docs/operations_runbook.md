# Sổ Tay Vận Hành Dữ Liệu & DBA (DBA Operations Runbook)

Tài liệu này là cẩm nang vận hành chuẩn (Runbook) dành cho Quản trị viên Cơ sở dữ liệu (DBA) và Data Engineers phụ trách quản lý dữ liệu lõi của nền tảng Lingoria.

---

## 1. Quy Trình Khởi Tạo Hệ Thống Từ Đầu (Bootstrap Workflow)

Sau khi nền tảng hạ tầng [lingoria-platform-deployment](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-platform-deployment) đã khởi chạy các container rỗng (`postgres`, `minio`, `redis`):

### Bước 1: Lấy mật khẩu và cấu hình kết nối
1. Tại repo `lingoria-platform-deployment`, chạy lệnh:
   ```bash
   make show-credentials
   ```
   Ghi nhận mật khẩu của **Postgres** và **MinIO**.
2. Tại repo `lingoria-core-db`, khởi tạo file cấu hình:
   ```bash
   make init-config
   ```
3. Mở file [.env](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/.env) và cập nhật:
   - `PG_SUPERUSER_PASSWORD=<mật_khẩu_postgres_vừa_lấy>`
   - `MINIO_ROOT_PASSWORD=<mật_khẩu_minio_vừa_lấy>`

---

### Bước 2: Declarative Provisioning Cấp Hệ Thống (PostgreSQL, MinIO, Redis)
Chạy các lệnh declarative provisioning đọc từ `configs/*.json`:
```bash
# 1. Tạo databases 'lingoria', 'airflow', roles và bật extensions theo configs/postgres.json
make pg-provision

# 2. Tạo 4 buckets, policies và users theo configs/minio.json
make minio-provision

# 3. Cấu hình ACL users và namespaces theo configs/redis.json
make redis-provision
```
> [!NOTE]
> Các lệnh `make *-provision` mang tính **Idempotent** tuyệt đối. Bạn có thể chạy lại bao nhiêu lần cũng an toàn mà không làm gián đoạn hay phát sinh lỗi trùng lặp.

---

### Bước 3: Khởi Tạo One-Time Cho Core Database `lingoria`
```bash
# Khởi tạo schemas, tables và nạp catalog seeds cho database 'lingoria'
make pg-init
```
> [!IMPORTANT]
> Lệnh `make pg-init` chỉ thực thi **1 lần duy nhất**. Nếu cơ sở dữ liệu đã có dữ liệu hoặc đã được khởi tạo, lệnh sẽ hiển thị thông báo an toàn và tự động dừng lại để bảo vệ dữ liệu.

---

## 2. Bảng Tra Cứu Toàn Bộ Lệnh Quản Trị & Chẩn Đoán Từng Tool

Hệ thống được thiết kế phân tách theo từng công cụ độc lập:

### 2.1 Quản trị PostgreSQL:
| Lệnh thao tác | Ý nghĩa |
| :--- | :--- |
| `make pg-provision` | Khởi tạo / đồng bộ DBs, users và extensions từ `configs/postgres.json` |
| `make pg-init` | Khởi tạo one-time 14 schemas và nạp catalog seeds cho DB `lingoria` |
| `make pg-list-db` | Liệt kê tất cả databases, owner, encoding và dung lượng |
| `make pg-list-users`| Liệt kê tất cả roles/users và phân quyền |
| `make pg-status` | Kiểm tra kết nối, uptime và số lượng active connections |
| `make pg-performance`| Đo buffer cache hit ratio, kiểm tra blocking locks và truy vấn chậm |
| `make pg-storage` | Phân tích chi tiết dung lượng từng bảng và index |
| `make pg-psql` | Mở interactive psql shell với app user (`lingoria`) |
| `make pg-psql-admin`| Mở interactive psql shell với superuser (`postgres`) |
| `make pg-backup` | Sao lưu toàn bộ database ra file trong `backups/` |
| `make pg-reset CONFIRM=YES` | Xoá toàn bộ 14 schemas và chạy lại `pg-init` từ đầu |

### 2.2 Quản trị MinIO:
| Lệnh thao tác | Ý nghĩa |
| :--- | :--- |
| `make minio-provision` | Khởi tạo buckets, download policies và users từ `configs/minio.json` |
| `make minio-list-buckets` | Liệt kê danh sách buckets, ngày tạo và dung lượng sử dụng |
| `make minio-list-users` | Liệt kê danh sách users và service accounts |
| `make minio-status` | Kiểm tra health status, uptime và thông số server |

### 2.3 Quản trị Redis:
| Lệnh thao tác | Ý nghĩa |
| :--- | :--- |
| `make redis-provision` | Khởi tạo ACL users và namespaces từ `configs/redis.json` |
| `make redis-list-keys` | Thống kê số lượng key theo từng namespace cấu hình |
| `make redis-list-users` | Liệt kê danh sách ACL users và rule phân quyền |
| `make redis-status` | Kiểm tra ping, uptime và số lượng client kết nối |
| `make redis-performance` | Đo lường tỷ lệ hit ratio và số operations/giây |
| `make redis-storage` | Phân tích chi tiết bộ nhớ RAM sử dụng và AOF persistence |
| `make redis-flush CONFIRM=YES` | Xoá sạch toàn bộ keys trong cache |

---

## 3. Quy Trình Sao Lưu & Khôi Phục (Backup & Restore)

### Sao lưu (Backup):
```bash
make pg-backup
```
File được xuất ra tại: `backups/lingoria_<YYYYMMDD_HHMMSS>.sql`.

### Khôi phục (Restore):
```bash
psql "$DATABASE_URL" < backups/lingoria_<timestamp>.sql
```

---

## 4. Xử Lý Sự Cố Thường Gặp (Troubleshooting)

### Sự cố 1: `psql: error: connection to server on socket failed: Connection refused`
- **Nguyên nhân:** Container PostgreSQL chưa được khởi động hoặc cổng port không khớp.
- **Khắc phục:** Đảm bảo container PostgreSQL đang chạy trong `lingoria-platform-deployment` và cổng kết nối trong `.env` là `55432`.

### Sự cố 2: `FATAL: password authentication failed for user "postgres"`
- **Nguyên nhân:** Mật khẩu trong `.env` không khớp với mật khẩu auto-generated trong container volume.
- **Khắc phục:** Chạy `make show-credentials` trong `lingoria-platform-deployment` để lấy mật khẩu chính xác và cập nhật vào `PG_SUPERUSER_PASSWORD`.
