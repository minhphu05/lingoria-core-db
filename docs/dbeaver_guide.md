# Hướng Dẫn Vận Hành Dữ Liệu Bằng DBeaver (DBeaver Guide)

Tài liệu này hướng dẫn chi tiết cách thiết lập kết nối và thực thi các câu lệnh SQL trong repository [lingoria-core-db](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db) bằng công cụ quản trị trực quan **DBeaver** (hoặc DataGrip / TablePlus / pgAdmin).

---

## 1. Thiết Lập 2 Connection Profiles Trong DBeaver

Để đảm bảo nguyên tắc bảo mật và phân quyền đúng chuẩn DBA, bạn nên tạo **2 kết nối riêng biệt** trong DBeaver:

### Profile 1: Kết Nối Superuser Quản Trị (DBA Superuser Connection)
- **Mục đích:** Dùng cho các tác vụ DBA cấp cao: tạo database mới, tạo roles/users, kích hoạt extensions, kiểm tra blocking locks toàn hệ thống.
- **Thông số cấu hình:**
  - **Connection Name:** `Lingoria - Postgres Superuser (DBA)`
  - **Database Driver:** `PostgreSQL`
  - **Host:** `localhost`
  - **Port:** `55432` *(cổng expose của container `lingoria-postgres`)*
  - **Database:** `postgres` *(database hệ thống mặc định)*
  - **Username:** `postgres`
  - **Password:** Lấy từ lệnh `make show-credentials` trong repo `lingoria-platform-deployment`.

---

### Profile 2: Kết Nối Application User Nghiệp Vụ (App Connection)
- **Mục đích:** Dùng cho phát triển nghiệp vụ hằng ngày: chạy schema migrations, nạp seed data, truy vấn bảng, kiểm tra quan hệ giữa các schemas.
- **Thông số cấu hình:**
  - **Connection Name:** `Lingoria - Core Database (App)`
  - **Database Driver:** `PostgreSQL`
  - **Host:** `localhost`
  - **Port:** `55432`
  - **Database:** `lingoria` *(sau khi đã chạy `sql/init/001_create_databases.sql`)*
  - **Username:** `lingoria`
  - **Password:** `lingoria_local_change_me` *(được tạo từ `sql/init/002_create_roles.sql`)*

---

## 2. Quy Trình Khởi Tạo & Chạy SQL Trên DBeaver

### Bước 1: Khởi Tạo Hệ Thống Bằng Superuser Connection
1. Kết nối vào Profile **Lingoria - Postgres Superuser (DBA)**.
2. Mở file [sql/init/001_create_databases.sql](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/sql/init/001_create_databases.sql) trong DBeaver:
   - Nhấn phím tắt `Alt + X` (Execute SQL Script) để tạo database `lingoria` và `airflow`.
3. Mở file [sql/init/002_create_roles.sql](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/sql/init/002_create_roles.sql):
   - Nhấn `Alt + X` để tạo user `lingoria` và cấp quyền sở hữu database `lingoria`.
4. Mở file [sql/init/003_extensions.sql](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/sql/init/003_extensions.sql):
   - Chuyển database context sang `lingoria` và nhấn `Alt + X` để kích hoạt các extensions (`vector`, `pgcrypto`, `citext`, `pg_trgm`).

---

### Bước 2: Chạy Migrations & Seeds Bằng App Connection
1. Kết nối vào Profile **Lingoria - Core Database (App)**.
2. Mở thư mục [sql/migrations/](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/sql/migrations/) và chạy tuần tự các file từ `0001` đến `0010`:
   - `0001_extensions.sql`: Tạo schema `platform` và bảng `schema_migrations`.
   - `0002_catalog.sql`: Tạo schema `catalog` và danh mục địa lý, ngôn ngữ.
   - `0003_content_learning.sql`: Tạo schemas `content` và `learning`.
   - `0004_ingestion_media.sql`: Tạo schemas `ingestion` và `media`.
   - `0005_linguistic.sql`: Tạo schema `linguistic` (lexemes, senses, grammar).
   - `0006_media_transcript_assessment.sql`: Tạo schema `assessment` và transcripts.
   - `0007_culture_progress_engagement.sql`: Tạo schemas `culture`, `progress`, `community`.
   - `0008_provenance_search_analytics.sql`: Tạo schemas `billing`, `notification`, `search`, `analytics`.
   - `0009_functions_indexes.sql`: Tạo các hàm trigger và chỉ mục tìm kiếm.
   - `0010_korean_source_support.sql`: Mở rộng hỗ trợ dữ liệu tiếng Hàn NIKL.
3. Mở file [sql/seeds/0001_catalog.sql](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/sql/seeds/0001_catalog.sql) và nhấn `Alt + X` để nạp dữ liệu mẫu ban đầu.

---

## 3. Sử Dụng Các Câu Lệnh Chẩn Đoán Của DBA (`sql/dba/`)

Khi cần kiểm tra hiệu năng hoặc dung lượng đĩa trong DBeaver, bạn chỉ cần mở các file trong thư mục [sql/dba/](file:///Users/kittnguyen/Documents/Project/Personal/lingoria-core-db/sql/dba/):
- **`check_table_sizes.sql`**: Xem bảng nào đang chiếm nhiều dung lượng nhất.
- **`check_active_locks.sql`**: Phát hiện transaction nào đang bị treo hoặc giữ khóa cản trở truy vấn khác.
- **`check_slow_queries.sql`**: Liệt kê các câu lệnh đang chạy quá 2 giây.
- **`check_index_usage.sql`**: Đo lường tỷ lệ tận dụng index để tối ưu hoá câu lệnh WHERE.

---

## 4. Mẹo Vận Hành Tránh Lỗi Trên DBeaver

- **Phím tắt thực thi:**
  - `Ctrl + Enter` (hoặc `Cmd + Enter` trên macOS): Chỉ chạy câu lệnh tại vị trí con trỏ chuột.
  - `Alt + X`: Chạy toàn bộ file script từ đầu đến cuối (Khuyên dùng cho migrations và init).
- **Tự động ngắt khi gặp lỗi (Stop on Error):**
  Trong cửa sổ SQL Editor của DBeaver, hãy đảm bảo icon **"Stop on error"** được bật (sáng) để script dừng lại ngay lập tức nếu một câu lệnh DDL bị lỗi.
