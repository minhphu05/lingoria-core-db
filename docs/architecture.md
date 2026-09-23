# Kiến Trúc Dữ Liệu & Ranh Giới Lược Đồ (Data Architecture & Schema Boundaries)

Tài liệu này mô tả toàn diện kiến trúc tầng dữ liệu lõi (Core Data Tier) của Lingoria, bao gồm phân định ranh giới 14 PostgreSQL schemas, chiến lược lưu trữ Object Storage trên MinIO và cơ chế bộ nhớ đệm trên Redis.

---

## 1. Nguyên Tắc Thiết Kế Cốt Lõi (Design Principles)

1. **Modular Monolith First**: Thiết kế cơ sở dữ liệu theo mô hình Modular Monolith. Mỗi PostgreSQL schema đại diện cho một ranh giới logic (Logical Service Boundary). Khi hệ thống mở rộng, các schema này có thể dễ dàng tách thành microservices độc lập mà không cần tái cấu trúc mô hình dữ liệu.
2. **Độc lập ngôn ngữ & địa phương**: `language != country != locale`. Các ngôn ngữ `/japanese`, `/korea`, `/china`, `/vietnam` được giải quyết động thông qua bảng `catalog.site`.
3. **Mục nội dung tái sử dụng (Composable Content Item)**: Bảng `content.content_item` đóng vai trò là xương sống kết nối giữa học tập (learning), văn hoá (culture), truyền thông (media) và đánh giá (assessment).
4. **Tách biệt nhị phân và siêu dữ liệu**: Tệp nhị phân nặng (audio, video, hình ảnh) được lưu trữ tập trung tại MinIO/S3; PostgreSQL chỉ lưu trữ siêu dữ liệu (metadata), chỉ số kích thước và lịch sử nguồn gốc (provenance).
5. **Bảo toàn lịch sử học tập**: Các bản sửa đổi (revisions) mang tính bất biến (immutable) để bảo vệ tiến trình học tập của người dùng.
6. **Nhận dạng người dùng trừu tượng**: Xác thực và tài khoản người dùng được quản lý bởi dịch vụ định danh bên ngoài; cơ sở dữ liệu lõi chỉ lưu trữ định danh dưới dạng UUID.

---

## 2. Chi Tiết 14 PostgreSQL Schemas

Toàn bộ hệ thống cơ sở dữ liệu `lingoria` được phân chia thành 14 schemas nghiệp vụ độc lập:

| # | Schema | Trách Nhiệm Nghiệp Vụ (Responsibility) | Các Bảng Chính |
| :-: | :--- | :--- | :--- |
| 1 | **`platform`** | Quản lý phiên bản migration và siêu dữ liệu nền tảng | `schema_migrations` |
| 2 | **`catalog`** | Định nghĩa ngôn ngữ, quốc gia, bảng chữ cái, cấp độ, chủ đề | `site`, `language`, `country`, `locale`, `level`, `topic` |
| 3 | **`content`** | Định danh nội dung, bản dịch đa ngữ, quan hệ và lịch sử phiên bản | `content_item`, `content_translation`, `content_relation`, `content_revision` |
| 4 | **`learning`** | Cấu trúc khoá học, học phần (unit), bài học (lesson) và các block bài giảng | `course`, `unit`, `lesson`, `lesson_block` |
| 5 | **`linguistic`** | Từ vựng, ngữ nghĩa, ngữ pháp, mẫu câu ví dụ và phân tích từ tố | `lexeme`, `sense`, `grammar_pattern`, `sentence`, `morpheme` |
| 6 | **`media`** | Siêu dữ liệu âm thanh, hình ảnh, thông tin người nói và bản ghi phụ đề (transcript) | `asset`, `media_item`, `speaker`, `transcript`, `transcript_segment` |
| 7 | **`assessment`** | Bài tập, câu hỏi trắc nghiệm, đáp án chuẩn và đánh giá phát âm AI | `exercise`, `exercise_prompt`, `attempt`, `evaluation` |
| 8 | **`culture`** | Thực thể văn hoá, phong tục, bài viết chuyên đề và câu chuyện biên tập | `cultural_entity`, `cultural_article`, `editorial_story` |
| 9 | **`progress`** | Trạng thái học tập người dùng, lịch ôn tập ngắt quãng (SRS), chuỗi ngày học và huy hiệu | `user_course_progress`, `user_lesson_state`, `srs_item`, `achievement` |
| 10 | **`community`** | Bình luận, phản hồi cảm xúc, theo dõi bạn học, báo cáo vi phạm | `comment`, `reaction`, `user_follow`, `moderation_report` |
| 11 | **`notification`** | Cấu hình nhận thông báo và lịch sử gửi tin nhắn (Email/Push) | `notification_preference`, `notification_log` |
| 12 | **`billing`** | Gói dịch vụ, trạng thái thuê bao và quyền lợi người dùng (Entitlements) | `subscription_plan`, `user_subscription`, `entitlement` |
| 13 | **`ingestion`** | Bản ghi nguồn dữ liệu thô, giấy phép bản quyền, nhật ký thu thập (crawling) | `source_record`, `license`, `import_job`, `provenance_record` |
| 14 | **`search` & `analytics`** | Vector embeddings (pgvector), chỉ mục Full-text và sự kiện phân tích hành vi | `search_document`, `vector_embedding`, `product_event` |

---

## 3. Chiến Lược Lưu Trữ MinIO Object Storage

MinIO đóng vai trò lưu trữ các đối tượng dữ liệu phi cấu trúc với 4 buckets chuẩn hoá:

```text
MinIO Object Storage/
├── lingoria-raw/              # Dữ liệu thu thập thô (Private - Chỉ Ingestion/ETL truy cập)
│   ├── dict_dumps/
│   └── web_scrapes/
├── lingoria-media-original/   # File âm thanh/video gốc chưa nén (Private - Airflow xử lý)
│   ├── speakers/
│   └── native_audio/
├── lingoria-media-derived/    # File đã xử lý WebP/MP3 tối ưu (Public Download Policy)
│   ├── pronunciations/
│   └── illustrations/
└── lingoria-local/            # Sandbox dành riêng cho dev thử nghiệm cục bộ
```

---

## 4. Chiến Lược Bộ Nhớ Đệm Redis Cache

Redis đảm nhiệm các tác vụ có yêu cầu độ trễ cực thấp:
- **Key Namespace Quy Ước:**
  - `lingoria:session:<user_uuid>`: Phiên đăng nhập người dùng (TTL 24h).
  - `lingoria:catalog:<locale>`: Bộ nhớ đệm danh mục hiển thị trang chủ (TTL 1h).
  - `lingoria:srs:queue:<user_uuid>`: Hàng đợi từ vựng cần ôn tập trong ngày.
  - `lingoria:ratelimit:<ip>`: Giới hạn tần suất gọi API (Rate limiting).
