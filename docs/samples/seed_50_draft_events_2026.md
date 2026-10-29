# Dữ liệu thử cuối năm 2026

File [`seed_50_draft_events_2026.sql`](seed_50_draft_events_2026.sql) dành cho PostgreSQL 16+, đã kiểm tra với schema backend V20 và V21. Chạy thủ công trong database development/test, không đặt vào thư mục Flyway tự động. File seed không phụ thuộc cột `events.max_tickets_per_user` của V21; giới hạn trong mỗi đợt bán vẫn là 4 vé/đơn và 8 vé/người. Giới hạn tổng vé/người ở cấp sự kiện để mặc định `NULL` nếu schema có cột này.

## Nội dung

- 50 sự kiện hư cấu từ **30/10/2026 09:00 đến 31/12/2026 16:00**, giờ Việt Nam; toàn bộ `DRAFT`, `published_at = NULL`. Ngày tạo yêu cầu là 29/10/2026, đã hơn 22 giờ nên sự kiện đầu bắt đầu sáng hôm sau.
- 10 tài khoản tổ chức, mỗi tài khoản sở hữu 5 sự kiện, có role `ORGANIZER` và `organizer_profiles`. Hồ sơ ngân hàng giữ mặc định `PENDING`, không giả xác minh ngân hàng.
- 10 thành phố, 10 địa điểm giả lập (sức chứa 1.000), 10 danh mục. Tái sử dụng danh mục có cùng slug mà không sửa dữ liệu cũ.
- 100 khu vực, 100 hạng vé, 100 đợt mở bán `DRAFT` và 100 bộ đếm tồn kho, chưa giữ hay bán vé. Có khu đứng và khu ngồi với số ghế đủ sức chứa.
- Hai mức vé mỗi sự kiện: Tiêu chuẩn và Đồng hành; giá 0–1.500.000 VND. Năm sự kiện cộng đồng miễn phí cả hai hạng vé. Đây là cấu hình đăng ký thử, không khẳng định đã hỗ trợ checkout miễn phí.
- UUID cố định, một transaction, có kiểm tra cuối script. Chạy lại trên bộ seed nguyên trạng không sinh thêm bản ghi. Không cập nhật/reset tài khoản hay sự kiện đã tồn tại. Script từ chối nếu sự kiện seed đã đổi trạng thái hoặc cấu hình vé không còn khớp các kiểm tra.

## Tài khoản đăng nhập

Email từ `organizer01@seed.smartevent.test` đến `organizer10@seed.smartevent.test`.

Mật khẩu demo cho cả 10 tài khoản: **`SeedOrg@2026!`**. SQL dùng `pgcrypto` để tạo BCrypt riêng cho từng tài khoản, tương thích bộ kiểm tra mật khẩu backend. Chạy lại không đổi mật khẩu đã sửa. Email thuộc miền thử nghiệm, không dùng để nhận thư.

## Cách chạy

Trong DBeaver/pgAdmin, mở file SQL với mã hóa UTF-8, chọn database thử nghiệm đã có schema backend và thực thi **toàn bộ script**, bao gồm `ROLLBACK;` ở đầu. File này chạy độc lập: lệnh đầu hủy transaction còn mở trong Query Tool, sau đó `BEGIN;` khởi tạo transaction riêng cho seed. Không ghép với công việc chưa commit khác. Nếu không có transaction đang mở, thông báo `there is no transaction in progress` chỉ là cảnh báo, script vẫn tiếp tục.

Nếu đã gặp lỗi `column "max_tickets_per_user" of relation "events" does not exist` hoặc `25P02 current transaction is aborted`, mở lại file seed mới đã sửa rồi chạy toàn bộ từ dòng `ROLLBACK;` đầu file. Không chỉ chạy tiếp từ dòng lỗi hoặc từ `BEGIN;`. Có thể mở Query Tool mới để tránh phần SQL cũ đang được chọn. Không cần thêm cột thủ công để chạy seed.

Lỗi đó cho biết bảng `events` ở database/schema đang chọn chưa có thay đổi của V21; có thể database chưa chạy migration hoặc pgAdmin đang trỏ database/schema khác với backend. Để chạy backend mới, cần cấu hình đúng `SPRING_DATASOURCE_URL` và khởi động backend để Flyway áp dụng các migration còn thiếu trước bước Hibernate kiểm tra schema. Không sửa trực tiếp `flyway_schema_history` hoặc thêm cột thay Flyway vì có thể làm migration V21 lỗi trùng cột về sau.

Có thể kiểm tra kết nối hiện tại trong pgAdmin bằng:

```sql
SELECT current_database(), current_schema();
SELECT table_schema, column_name
FROM information_schema.columns
WHERE table_name = 'events' AND column_name = 'max_tickets_per_user';
```

Hoặc dùng `psql` (đường dẫn dưới đây tính từ thư mục repository backend):

```powershell
psql -X -v ON_ERROR_STOP=1 -h localhost -p 5432 -U <db_user> -d <db_name> -f docs/samples/seed_50_draft_events_2026.sql
```

`pgcrypto` đã được tạo từ migration V1. Script không cần quyền tạo extension. Lịch được cố định theo năm 2026, không dùng `NOW() + ...` để tránh trượt sang năm 2027 khi chạy lại.

SQL không tải ảnh lên MinIO và không tạo bản ghi ảnh không có file thật. Khi gửi duyệt, **tải banner thật qua màn hình quản lý**, kiểm tra cấu hình vé có sẵn rồi dùng thao tác gửi duyệt của sự kiện. Luồng tạo nhanh cấu hình lại không phù hợp vì các bản nháp này đã có khu vực và vé.

## Kết quả kiểm tra

Đã kiểm tra ngày 29/10/2026 trên PostgreSQL 16 trong container riêng, không mở cổng mạng hay gắn volume dữ liệu dự án. Áp dụng SQL migration V1–V21, sau đó chạy file seed hai lần trong cùng phiên kết nối: lần hai không thêm bản ghi nghiệp vụ. Kết quả đúng 50 sự kiện nháp, 10 tổ chức (mỗi tổ chức 5 sự kiện), 10 thành phố (mỗi thành phố 5 sự kiện), 100 hạng vé/đợt bán/tồn kho và 4.250 ghế. Kiểm tra BCrypt của 10 mật khẩu demo, role/hồ sơ tổ chức, sức chứa, liên kết bảng, lịch bán và dữ liệu sự kiện cũ đều đạt. Chưa kiểm tra đăng nhập qua HTTP hoặc tích hợp AI.

Sau báo lỗi thiếu `max_tickets_per_user`, đã sửa file và kiểm tra lại trên hai database độc lập: một schema V1–V20 chưa có cột này và một schema V1–V21 có cột này. Trên mỗi database đều chạy seed hai lần trong cùng phiên và kiểm tra số lượng, mật khẩu, quan hệ, ghế, sức chứa và lịch: cả hai đều đạt.

Sau báo lỗi `25P02`, đã thêm `ROLLBACK;` đầu file và tái hiện transaction bị lỗi trên PostgreSQL 16/schema V20. Chạy bản seed mới ngay trong phiên bị lỗi đã khôi phục transaction, commit đủ 50 bản nháp; chạy lần hai vẫn giữ nguyên số lượng. Đây là kiểm tra qua psql, chưa thao tác trực tiếp giao diện pgAdmin của người dùng.

## Đủ để thử AI chưa?

**Đủ làm dữ liệu mẫu để thử giao diện tổ chức, phân trang, quan hệ sự kiện–vé và kiểm tra sự kiện nháp bị ẩn. Chưa đủ để thử trọn luồng chatbot tìm sự kiện hoặc để huấn luyện/đánh giá mô hình.**

1. Backend `EventQueryService`/`EventRepository` chỉ công khai sự kiện `PUBLISHED`. Adapter AI cũng từ chối sự kiện chưa công bố. Vì vậy chatbot khách hàng không được đọc 50 bản nháp này; không dùng tài khoản tổ chức để vượt giới hạn đó.
2. Trong cấu hình hiện tại của `ai-service`, business tool mặc định tắt; LLM/QLoRA chưa được tích hợp. Seed database không tự bật tích hợp. Chỉ bật công cụ sau khi các gate tích hợp và bảo mật tương ứng có bằng chứng đạt yêu cầu.
3. Để demo tìm sự kiện/so sánh giá, sau khi thêm banner hãy dùng UI tổ chức/admin duyệt một phần dữ liệu trên môi trường thử và kích hoạt đợt bán qua luồng nghiệp vụ phù hợp. Có thể giữ phần còn lại ở `DRAFT` để thử quyền truy cập. Script này giữ nguyên yêu cầu ban đầu: cả 50 sự kiện là nháp.
4. Bổ sung một bộ câu hỏi tiếng Việt có đáp án kỳ vọng: tìm theo thành phố/ngày/danh mục/ngân sách, hỏi tiếp nhiều lượt, không có kết quả, từ chối đọc bản nháp, và yêu cầu mua/giữ vé phải điều hướng đúng. Số lượng sự kiện không thay thế bộ hội thoại gán nhãn và tập kiểm tra độc lập.
5. Năm mươi sự kiện đủ cho smoke test ban đầu của tìm kiếm khi đã được công bố và tích hợp đúng. Muốn đánh giá tư vấn tồn kho cần thêm tình huống còn ít vé/hết vé/đợt bán chưa mở/đã đóng, tạo qua fixture thử riêng hoặc luồng nghiệp vụ. Bộ này không có đơn hàng, thanh toán, vé đã phát hành hay hành vi người dùng, nên không đánh giá được các luồng đó hoặc mô hình gợi ý dựa trên hành vi.
6. Câu hỏi chính sách/hoàn tiền cần corpus RAG được duyệt, không lấy mô tả sự kiện giả làm chính sách. Dữ liệu huấn luyện không được chứa mật khẩu, hash, token hay thông tin nhạy cảm.

Nhận định trên dựa trên mã backend, `ai-service/README.md`, `configs/runtime_tool_registry.yaml` và ADR-001 hiện có trong workspace; không hàm ý đã chạy kiểm thử tích hợp AI.
