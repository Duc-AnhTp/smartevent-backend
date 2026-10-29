-- SmartEvent: 50 sự kiện HƯ CẤU, 10 tài khoản tổ chức, 30/10–31/12/2026.
-- PostgreSQL 16+, schema backend đã chạy Flyway V1..V21.
-- Chạy thủ công trên database development/test; đây KHÔNG phải Flyway migration.
-- Tài khoản: organizer01@seed.smartevent.test .. organizer10@seed.smartevent.test
-- Mật khẩu demo dùng chung: SeedOrg@2026! (BCrypt riêng cho từng tài khoản).
-- Mọi event và sale phase đều DRAFT; published_at = NULL.
-- Không tạo files/banner giả: tải banner thật qua UI trước khi gửi duyệt.
-- Chạy lại không nhân bản, không reset mật khẩu/trạng thái/tồn kho hiện có.
-- Nếu đã xuất bản sự kiện hoặc sửa cấu hình vé, kiểm tra lại dữ liệu trước khi chạy lại.

BEGIN;
SET LOCAL client_encoding = 'UTF8';
SET LOCAL TIME ZONE 'Asia/Ho_Chi_Minh';
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '120s';
SELECT pg_advisory_xact_lock(hashtext('smartevent-seed-50-draft-2026'));

CREATE OR REPLACE FUNCTION pg_temp.seed_2026_id(kind text, n integer) RETURNS uuid
LANGUAGE sql IMMUTABLE AS $$
    SELECT md5('smartevent-seed-50-draft-2026/' || kind || '/' || n::text)::uuid;
$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'ORGANIZER') THEN
        RAISE EXCEPTION 'Thiếu role ORGANIZER. Hãy chạy migration backend trước.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM users u JOIN generate_series(1, 10) n
          ON u.id = pg_temp.seed_2026_id('user', n)
          OR u.email = 'organizer' || lpad(n::text, 2, '0') || '@seed.smartevent.test'
        WHERE u.id <> pg_temp.seed_2026_id('user', n)
           OR u.email <> 'organizer' || lpad(n::text, 2, '0') || '@seed.smartevent.test'
    ) THEN
        RAISE EXCEPTION 'Email hoặc UUID seed trùng tài khoản khác; không ghi đè.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM events e JOIN generate_series(1, 50) n
          ON e.id = pg_temp.seed_2026_id('event', n)
        WHERE e.status <> 'DRAFT' OR e.published_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Có sự kiện seed đã đổi trạng thái. Không tự chuyển về DRAFT.';
    END IF;
END;
$$;

CREATE TEMP TABLE seed_2026_categories (
    n integer PRIMARY KEY, name text, slug text, company text
) ON COMMIT DROP;
INSERT INTO seed_2026_categories VALUES
 (1, 'Âm Nhạc & Concert', 'am-nhac-concert', 'Studio Giai Điệu Demo'),
 (2, 'Lễ Hội & Festival', 'le-hoi-festival', 'Không Gian Lễ Hội Demo'),
 (3, 'Hội Thảo & Workshop', 'hoi-thao-workshop', 'Xưởng Kỹ Năng Demo'),
 (4, 'Thể Thao & Esports', 'the-thao-esports', 'Nhịp Sống Thể Thao Demo'),
 (5, 'Sân Khấu & Kịch Nghệ', 'san-khau-kich-nghe', 'Sân Khấu Mở Demo'),
 (6, 'Giáo Dục & Nghề Nghiệp', 'giao-duc-nghe-nghiep', 'Học Viện Tương Lai Demo'),
 (7, 'Kinh Doanh & Khởi Nghiệp', 'kinh-doanh-khoi-nghiep', 'Kết Nối Doanh Nghiệp Demo'),
 (8, 'Ẩm Thực & Đồ Uống', 'am-thuc-do-uong', 'Bếp Việt Trải Nghiệm Demo'),
 (9, 'Nghệ Thuật & Triển Lãm', 'nghe-thuat-trien-lam', 'Phòng Tranh Sáng Tạo Demo'),
 (10, 'Cộng Đồng & Thiện Nguyện', 'cong-dong-thien-nguyen', 'Câu Lạc Bộ Cộng Đồng Demo');

INSERT INTO users (id, email, password_hash, full_name, status)
SELECT pg_temp.seed_2026_id('user', n),
       'organizer' || lpad(n::text, 2, '0') || '@seed.smartevent.test',
       crypt('SeedOrg@2026!', gen_salt('bf', 10)),
       'Ban tổ chức ' || lpad(n::text, 2, '0') || ' — ' || company, 'ACTIVE'
FROM seed_2026_categories
ON CONFLICT (id) DO NOTHING;

INSERT INTO user_roles (id, user_id, role_id)
SELECT pg_temp.seed_2026_id('user-role', c.n), pg_temp.seed_2026_id('user', c.n), r.id
FROM seed_2026_categories c CROSS JOIN roles r WHERE r.name = 'ORGANIZER'
ON CONFLICT (user_id, role_id) DO NOTHING;

INSERT INTO organizer_profiles (id, user_id, company_name, business_address, bank_account_status)
SELECT pg_temp.seed_2026_id('organizer-profile', n), pg_temp.seed_2026_id('user', n),
       company, 'Địa chỉ tổ chức giả lập, chỉ dùng kiểm thử SmartEvent', 'PENDING'
FROM seed_2026_categories
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO categories (id, name, slug, description, status)
SELECT pg_temp.seed_2026_id('category', n), name, slug,
       'Nhóm sự kiện dùng trong bộ dữ liệu kiểm thử cuối năm 2026.', 'ACTIVE'
FROM seed_2026_categories
ON CONFLICT (slug) DO NOTHING;

CREATE TEMP TABLE seed_2026_venues (
    n integer PRIMARY KEY, city text, name text, address text,
    latitude numeric, longitude numeric
) ON COMMIT DROP;
-- Tất cả địa điểm dưới đây là giả lập; tọa độ chỉ xấp xỉ trung tâm thành phố.
INSERT INTO seed_2026_venues VALUES
 (1, 'Hà Nội', 'Không gian Hồ Gươm Demo', 'Địa điểm thử nghiệm 01, Hà Nội', 21.028500, 105.854200),
 (2, 'Hồ Chí Minh', 'Trung tâm Sài Gòn Demo', 'Địa điểm thử nghiệm 02, Hồ Chí Minh', 10.776900, 106.700900),
 (3, 'Đà Nẵng', 'Không gian Sông Hàn Demo', 'Địa điểm thử nghiệm 03, Đà Nẵng', 16.054400, 108.202200),
 (4, 'Huế', 'Trung tâm Sông Hương Demo', 'Địa điểm thử nghiệm 04, Huế', 16.463700, 107.590900),
 (5, 'Đà Lạt', 'Không gian Cao Nguyên Demo', 'Địa điểm thử nghiệm 05, Đà Lạt', 11.940400, 108.458300),
 (6, 'Cần Thơ', 'Trung tâm Tây Đô Demo', 'Địa điểm thử nghiệm 06, Cần Thơ', 10.045200, 105.746900),
 (7, 'Hải Phòng', 'Không gian Thành Phố Cảng Demo', 'Địa điểm thử nghiệm 07, Hải Phòng', 20.844900, 106.688100),
 (8, 'Nha Trang', 'Trung tâm Biển Xanh Demo', 'Địa điểm thử nghiệm 08, Nha Trang', 12.238800, 109.196700),
 (9, 'Vũng Tàu', 'Không gian Sóng Biển Demo', 'Địa điểm thử nghiệm 09, Vũng Tàu', 10.346000, 107.084300),
 (10, 'Quy Nhơn', 'Trung tâm Miền Biển Demo', 'Địa điểm thử nghiệm 10, Quy Nhơn', 13.782000, 109.219700);

INSERT INTO venues (id, name, address, city, latitude, longitude, capacity, status)
SELECT pg_temp.seed_2026_id('venue', n), name, address, city, latitude, longitude, 1000, 'ACTIVE'
FROM seed_2026_venues
ON CONFLICT (id) DO NOTHING;

CREATE TEMP TABLE seed_2026_content (
    n integer PRIMARY KEY, name text, topic text, audience text, base_price numeric
) ON COMMIT DROP;
INSERT INTO seed_2026_content VALUES
 (1, 'Acoustic Chạm Thu', 'Guitar mộc, piano và những ca khúc nhẹ nhàng cuối thu', 'Người yêu nhạc acoustic và nhóm bạn', 180000),
 (2, 'Lễ Hội Sắc Màu Cuối Thu', 'Gian hàng thủ công, trò chơi tập thể và trình diễn đường phố', 'Gia đình và bạn trẻ yêu không khí lễ hội', 90000),
 (3, 'Workshop AI Trong Công Việc', 'Thực hành viết yêu cầu cho AI và kiểm tra kết quả trả lời', 'Nhân viên văn phòng mới bắt đầu sử dụng AI', 250000),
 (4, 'Ngày Hội Chạy Bộ Cộng Đồng', 'Chạy bộ giải trí cự ly 5 km, khởi động và phục hồi cơ bản', 'Người mới chạy bộ và nhóm đồng nghiệp', 120000),
 (5, 'Kịch Ngắn Chuyện Phố Mình', 'Các tiểu phẩm đời sống đô thị và giao lưu sau buổi diễn', 'Khán giả yêu sân khấu và sinh viên', 200000),
 (6, 'Ngày Hội Định Hướng Nghề Công Nghệ', 'Khám phá nghề lập trình, dữ liệu và thiết kế sản phẩm', 'Sinh viên và người muốn chuyển nghề', 80000),
 (7, 'Kết Nối Startup Giai Đoạn Sớm', 'Thuyết trình ý tưởng, phản biện mô hình kinh doanh và networking', 'Nhà sáng lập và người quan tâm khởi nghiệp', 350000),
 (8, 'Trải Nghiệm Cà Phê Việt', 'Tìm hiểu hạt cà phê, thử pha phin và nếm thử có hướng dẫn', 'Người yêu cà phê và khách mới tìm hiểu', 220000),
 (9, 'Triển Lãm Ảnh Nhịp Sống Việt', 'Ảnh đời thường, chuyện hậu trường và góc trải nghiệm chụp ảnh', 'Người yêu nhiếp ảnh và nghệ thuật thị giác', 60000),
 (10, 'Đổi Sách Gửi Trao Tri Thức', 'Mang sách đã đọc để trao đổi và tham gia góc đọc cộng đồng', 'Học sinh, sinh viên và gia đình', 0),
 (11, 'Jazz Dưới Ánh Đèn', 'Đêm nhạc jazz cùng các phần ứng tác và giới thiệu nhạc cụ', 'Khán giả thích nhạc jazz và trải nghiệm nghe trực tiếp', 420000),
 (12, 'Lễ Hội Văn Hóa Ba Miền', 'Giao lưu văn hóa vùng miền, trò chơi dân gian và gian hàng trải nghiệm', 'Gia đình và người yêu văn hóa Việt', 100000),
 (13, 'Workshop Nhiếp Ảnh Điện Thoại', 'Bố cục, ánh sáng và chỉnh ảnh chân dung bằng điện thoại', 'Người sáng tạo nội dung mới bắt đầu', 180000),
 (14, 'Giải Cầu Lông Giao Lưu', 'Thi đấu phong trào theo nhóm và trao đổi kỹ thuật cầu lông', 'Người chơi cầu lông nghiệp dư', 150000),
 (15, 'Hài Độc Thoại Chuyện Đi Làm', 'Những góc nhìn hài hước về công sở và giao lưu với người biểu diễn', 'Khán giả trưởng thành và nhóm đồng nghiệp', 250000),
 (16, 'Lớp CV Và Phỏng Vấn Đầu Tiên', 'Chỉnh CV, luyện phỏng vấn và nhận góp ý theo tình huống', 'Sinh viên năm cuối và người tìm việc lần đầu', 120000),
 (17, 'Diễn Đàn Chuyển Đổi Số SME', 'Thảo luận quy trình số, dữ liệu khách hàng và chi phí triển khai', 'Chủ doanh nghiệp vừa và nhỏ', 500000),
 (18, 'Lớp Làm Bánh Cuối Tuần', 'Thực hành cân nguyên liệu, nướng bánh và trang trí bánh cơ bản', 'Người yêu bếp và các cặp đôi', 380000),
 (19, 'Xưởng Vẽ Màu Nước Cho Người Mới', 'Luyện phối màu, vẽ phong cảnh đơn giản và trưng bày bài thực hành', 'Người mới học vẽ từ 16 tuổi', 240000),
 (20, 'Ngày Sống Xanh Cùng Khu Phố', 'Phân loại rác, đổi đồ dùng và chia sẻ cách giảm nhựa dùng một lần', 'Cư dân địa phương và tình nguyện viên', 0),
 (21, 'Indie Gặp Nhau Tháng Mười Một', 'Các bản nhạc indie nguyên tác và câu chuyện sáng tác', 'Bạn trẻ yêu nhạc indie', 280000),
 (22, 'Ngày Hội Gia Đình Sáng Tạo', 'Trò chơi hợp tác, góc thủ công và hoạt động cha mẹ cùng con', 'Gia đình có trẻ từ 6 tuổi', 130000),
 (23, 'Workshop Quản Lý Tài Chính Cá Nhân', 'Lập ngân sách, ghi chép chi tiêu và phân biệt mục tiêu tiết kiệm', 'Người mới đi làm muốn quản lý chi tiêu', 200000),
 (24, 'Esports Giao Lưu Sinh Viên', 'Các trận đấu biểu diễn, phân tích chiến thuật và giao lưu đội tuyển phong trào', 'Sinh viên yêu thể thao điện tử', 90000),
 (25, 'Nhạc Kịch Những Lá Thư', 'Câu chuyện gia đình kể bằng âm nhạc và diễn xuất sân khấu', 'Khán giả yêu nhạc kịch', 450000),
 (26, 'Ngày Hội Tiếng Anh Giao Tiếp', 'Thực hành hội thoại qua trò chơi, kể chuyện và làm việc nhóm', 'Người học tiếng Anh trình độ cơ bản', 100000),
 (27, 'Networking Sản Phẩm Và Thiết Kế', 'Trao đổi nghiên cứu người dùng, quản lý sản phẩm và thiết kế trải nghiệm', 'Product manager, designer và người chuyển ngành', 300000),
 (28, 'Khám Phá Món Chay Việt', 'Giới thiệu nguyên liệu thực vật và thực hành món chay đơn giản', 'Người muốn tìm hiểu nấu ăn chay', 260000),
 (29, 'Triển Lãm Thủ Công Đương Đại', 'Trưng bày gốm, giấy và dệt cùng câu chuyện của người làm nghề', 'Người yêu thủ công và thiết kế', 80000),
 (30, 'Kết Nối Tình Nguyện Viên Mùa Đông', 'Giới thiệu dự án cộng đồng và ghép nhóm theo kỹ năng tình nguyện', 'Sinh viên và người muốn tham gia hoạt động cộng đồng', 0),
 (31, 'Piano Và Những Ngày Cuối Năm', 'Độc tấu piano, nhạc phim và phần chia sẻ cảm nhận âm nhạc', 'Khán giả thích không gian âm nhạc yên tĩnh', 550000),
 (32, 'Lễ Hội Ánh Sáng Tháng Mười Hai', 'Không gian đèn trang trí, biểu diễn nghệ thuật và hoạt động chụp ảnh', 'Nhóm bạn và gia đình', 160000),
 (33, 'Workshop Dữ Liệu Với Excel', 'Làm sạch dữ liệu, bảng tổng hợp và trực quan hóa báo cáo cơ bản', 'Nhân viên văn phòng và sinh viên kinh tế', 280000),
 (34, 'Yoga Và Vận Động Nhẹ', 'Chuỗi động tác cơ bản, thở chậm và thư giãn có hướng dẫn', 'Người mới tập yoga từ 18 tuổi', 140000),
 (35, 'Múa Đương Đại Dòng Chảy', 'Biểu diễn múa chủ đề chuyển động đô thị và trò chuyện với nhóm diễn', 'Người yêu múa và nghệ thuật biểu diễn', 320000),
 (36, 'Lớp Kỹ Năng Thuyết Trình', 'Xây dựng thông điệp, luyện giọng nói và thực hành trình bày ngắn', 'Sinh viên và người đi làm', 180000),
 (37, 'Hội Thảo Thương Mại Điện Tử', 'Vận hành gian hàng, chăm sóc khách hàng và đọc số liệu bán hàng', 'Chủ cửa hàng và người bán hàng trực tuyến', 400000),
 (38, 'Trải Nghiệm Trà Và Bánh', 'Tìm hiểu trà Việt, thực hành pha trà và kết hợp bánh dùng kèm', 'Người yêu trà và trải nghiệm ẩm thực', 300000),
 (39, 'Xưởng Gốm Món Quà Tự Tay', 'Nặn gốm cơ bản, tạo hình cốc nhỏ và trang trí sản phẩm', 'Nhóm bạn và người yêu thủ công', 350000),
 (40, 'Chợ Đồ Cũ Gây Quỹ Cộng Đồng', 'Trao đổi đồ còn sử dụng tốt và tìm hiểu hoạt động gây quỹ giả lập', 'Cư dân địa phương và gia đình', 0),
 (41, 'Đêm Nhạc Giai Điệu Mùa Đông', 'Các bản tình ca mùa đông với ban nhạc biểu diễn trực tiếp', 'Khán giả yêu nhạc pop và ballad', 650000),
 (42, 'Lễ Hội Quà Tặng Cuối Năm', 'Gian hàng quà thủ công, trang trí thiệp và hoạt động gia đình', 'Gia đình và người tìm ý tưởng quà tặng', 120000),
 (43, 'Workshop Lập Kế Hoạch Năm Mới', 'Tổng kết mục tiêu cá nhân và xây dựng kế hoạch hành động cho năm 2027', 'Người đi làm và sinh viên', 220000),
 (44, 'Giải Cờ Vua Giao Lưu Cuối Năm', 'Đấu cờ phong trào, phân tích ván đấu và chia sẻ kỹ năng cơ bản', 'Người chơi cờ vua từ 12 tuổi', 100000),
 (45, 'Kịch Gia Đình Bữa Cơm Cuối Năm', 'Vở kịch về sum họp và đối thoại giữa các thế hệ', 'Gia đình và khán giả yêu kịch nói', 280000),
 (46, 'Ngày Hội Học Tập Và Hướng Nghiệp', 'Gặp gỡ người làm nghề, hỏi đáp lộ trình học và trải nghiệm kỹ năng', 'Học sinh cuối cấp và phụ huynh', 90000),
 (47, 'Diễn Đàn Nhà Sáng Lập Cuối Năm', 'Tổng kết bài học vận hành, xây đội ngũ và kết nối đối tác', 'Nhà sáng lập và quản lý doanh nghiệp', 750000),
 (48, 'Bếp Ấm Mùa Lễ Hội', 'Thực hành thực đơn liên hoan, trang trí bàn ăn và chia sẻ món ăn', 'Người yêu nấu ăn và nhóm gia đình', 480000),
 (49, 'Triển Lãm Minh Họa Chào Năm Mới', 'Tranh minh họa, thiết kế lịch và góc giao lưu cùng người sáng tạo', 'Người yêu minh họa và thiết kế đồ họa', 70000),
 (50, 'Gặp Gỡ Cộng Đồng Khép Lại 2026', 'Chia sẻ câu chuyện năm cũ, hoạt động kết nối và viết lời chúc năm mới', 'Cộng đồng địa phương và tình nguyện viên', 0);

CREATE TEMP TABLE seed_2026_events ON COMMIT DROP AS
SELECT c.*, ((c.n - 1) % 10) + 1 AS category_n,
       ((c.n - 1 + ((c.n - 1) / 10) * 3) % 10) + 1 AS venue_n,
       pg_temp.seed_2026_id('event', c.n) AS event_id,
       ((DATE '2026-10-30' + round((c.n - 1) * 62.0 / 49)::integer)
           + make_time(9 + ((c.n - 1) % 4) * 3, 0, 0))
           AT TIME ZONE 'Asia/Ho_Chi_Minh' AS starts_at
FROM seed_2026_content c;

INSERT INTO events (id, organizer_id, venue_id, name, slug, description,
                    start_time, end_time, status, city, published_at, max_tickets_per_user)
SELECT e.event_id, pg_temp.seed_2026_id('user', e.category_n),
       pg_temp.seed_2026_id('venue', e.venue_n), e.name || ' 2026',
       'seed-2026-draft-' || lpad(e.n::text, 3, '0'),
       format('%s. Đối tượng: %s. Địa điểm: %s, %s. '
              'Chương trình dự kiến 4 giờ: đón khách, nội dung chính, giao lưu và tổng kết. '
              'Giá vé tiêu chuẩn dự kiến: %s VND; thông tin còn có thể thay đổi. '
              'Đây là sự kiện hư cấu trong bộ dữ liệu thử nghiệm, chưa công bố và chưa mở bán.',
              e.topic, e.audience, v.name, v.city, e.base_price),
       e.starts_at, e.starts_at + interval '4 hours', 'DRAFT', v.city, NULL, 8
FROM seed_2026_events e JOIN seed_2026_venues v ON v.n = e.venue_n
ON CONFLICT (id) DO NOTHING;

INSERT INTO event_categories (event_id, category_id)
SELECT e.event_id, c.id
FROM seed_2026_events e JOIN seed_2026_categories sc ON sc.n = e.category_n
JOIN categories c ON c.slug = sc.slug
ON CONFLICT (event_id, category_id) DO NOTHING;

CREATE TEMP TABLE seed_2026_tiers ON COMMIT DROP AS
SELECT e.*, t.tier,
       pg_temp.seed_2026_id('area', e.n * 10 + t.tier) AS area_id,
       pg_temp.seed_2026_id('ticket-type', e.n * 10 + t.tier) AS type_id,
       pg_temp.seed_2026_id('sale-phase', e.n * 10 + t.tier) AS phase_id,
       CASE WHEN e.category_n IN (1, 3, 5, 6, 7) THEN 'SEATED' ELSE 'STANDING' END AS area_type,
       CASE WHEN t.tier = 1 THEN 80 + ((e.n - 1) % 5) * 40
            ELSE 20 + ((e.n - 1) % 5) * 10 END AS capacity,
       CASE WHEN t.tier = 1 THEN 'Tiêu chuẩn' ELSE 'Đồng hành' END AS tier_name,
       CASE WHEN t.tier = 1 THEN e.base_price ELSE e.base_price * 2 END AS price
FROM seed_2026_events e CROSS JOIN (VALUES (1), (2)) t(tier);

INSERT INTO event_areas (id, event_id, name, area_type, capacity, sort_order, description)
SELECT area_id, event_id, 'Khu ' || tier_name, area_type, capacity, tier,
       CASE WHEN area_type = 'SEATED' THEN 'Ghế ngồi có số, 10 ghế mỗi hàng.'
            ELSE 'Khu vực đứng tự do, không có ghế đánh số.' END
FROM seed_2026_tiers
ON CONFLICT (id) DO NOTHING;

INSERT INTO event_seats (id, event_area_id, row_name, seat_number, label, status)
SELECT pg_temp.seed_2026_id('seat-' || t.n || '-' || t.tier, s), t.area_id,
       chr(65 + (s - 1) / 10), lpad((((s - 1) % 10) + 1)::text, 2, '0'),
       chr(65 + (s - 1) / 10) || '-' || lpad((((s - 1) % 10) + 1)::text, 2, '0'), 'AVAILABLE'
FROM seed_2026_tiers t CROSS JOIN LATERAL generate_series(1, t.capacity) s
WHERE t.area_type = 'SEATED'
ON CONFLICT (event_area_id, row_name, seat_number) DO NOTHING;

INSERT INTO ticket_types (id, event_id, event_area_id, name, description, status)
SELECT type_id, event_id, area_id, 'Vé ' || tier_name,
       CASE WHEN tier = 1 THEN 'Tham dự nội dung chính của sự kiện.'
            ELSE 'Tham dự nội dung chính và phiên giao lưu mở rộng; không bao gồm dịch vụ ngoài mô tả.' END,
       'ACTIVE'
FROM seed_2026_tiers
ON CONFLICT (id) DO NOTHING;

INSERT INTO ticket_sale_phases (id, ticket_type_id, name, price, quantity,
                               sale_start_at, sale_end_at, max_per_order, max_per_user, status)
SELECT phase_id, type_id, 'Đợt dự kiến cuối năm 2026', price, capacity,
       TIMESTAMPTZ '2026-10-29 22:00:00+07', starts_at - interval '30 minutes', 4, 8, 'DRAFT'
FROM seed_2026_tiers
ON CONFLICT (id) DO NOTHING;

INSERT INTO inventory_counters (id, event_id, event_area_id, ticket_type_id, sale_phase_id,
                                total_quantity, held_quantity, sold_quantity)
SELECT pg_temp.seed_2026_id('inventory', n * 10 + tier), event_id, area_id, type_id, phase_id,
       capacity, 0, 0
FROM seed_2026_tiers
ON CONFLICT (sale_phase_id) DO NOTHING;

INSERT INTO event_payment_methods (event_id, method, enabled)
SELECT event_id, 'VNPAY', true FROM seed_2026_events
ON CONFLICT (event_id, method) DO NOTHING;

-- Bất kỳ kiểm tra nào thất bại đều rollback toàn bộ lần chạy.
DO $$
BEGIN
    IF (SELECT count(*) FROM events e JOIN seed_2026_events s ON s.event_id = e.id
        WHERE e.status = 'DRAFT' AND e.published_at IS NULL
          AND e.start_time >= TIMESTAMPTZ '2026-10-29 22:00:00+07'
          AND e.end_time < TIMESTAMPTZ '2027-01-01 00:00:00+07') <> 50 THEN
        RAISE EXCEPTION 'Cần đúng 50 sự kiện DRAFT trong khoảng ngày đã chọn.';
    END IF;
    IF (SELECT count(*) FROM users u JOIN seed_2026_categories c
        ON u.id = pg_temp.seed_2026_id('user', c.n)
        WHERE u.status = 'ACTIVE' AND u.deleted_at IS NULL) <> 10 THEN
        RAISE EXCEPTION 'Cần đúng 10 tài khoản tổ chức đang hoạt động.';
    END IF;
    IF (SELECT count(*) FROM ticket_sale_phases p JOIN seed_2026_tiers t ON t.phase_id = p.id
        JOIN inventory_counters i ON i.sale_phase_id = p.id
        WHERE p.status = 'DRAFT' AND i.total_quantity = p.quantity
          AND i.held_quantity = 0 AND i.sold_quantity = 0) <> 100 THEN
        RAISE EXCEPTION 'Cấu hình vé đã khác bản seed; không reset dữ liệu đã thay đổi.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM event_areas a JOIN seed_2026_tiers t ON t.area_id = a.id
        WHERE a.capacity <> t.capacity OR a.area_type <> t.area_type
           OR (a.area_type = 'SEATED' AND a.capacity <>
               (SELECT count(*) FROM event_seats s WHERE s.event_area_id = a.id))
    ) THEN
        RAISE EXCEPTION 'Sức chứa hoặc số ghế không khớp; không tự sửa cấu hình hiện có.';
    END IF;
END;
$$;

-- Kết quả kiểm tra, không trả hash mật khẩu hay token.
SELECT count(*) AS event_count, count(DISTINCT e.organizer_id) AS organizer_count,
       count(DISTINCT e.city) AS city_count, min(e.start_time) AS first_event,
       max(e.end_time) AS last_event_end
FROM events e JOIN seed_2026_events s ON s.event_id = e.id;

SELECT u.email, p.company_name, count(e.id) AS draft_events
FROM seed_2026_categories c JOIN users u ON u.id = pg_temp.seed_2026_id('user', c.n)
JOIN organizer_profiles p ON p.user_id = u.id
JOIN events e ON e.organizer_id = u.id
JOIN seed_2026_events s ON s.event_id = e.id
GROUP BY u.email, p.company_name ORDER BY u.email;

COMMIT;
