## 2026-11-05T09:58:45Z

Tạo một team AI Agent gồm 1 leader, 1 backend coder, 1 frontend coder, 1 Athletic Coach, 1 tester, 1 reviewer. Athletic Coach có nhiệm vụ cố vấn luật thể thức thi đấu cho team để team hiểu và thiết kế ứng dụng đúng mục đích. Leader sẽ nhận nhiệm vụ mà người dùng yêu cầu để thực hiện phân tích và đưa công việc phù hợp cho team. Leader có thể tạo thêm AI Agent khác phù hợp với công việc yêu cầu.

Triển khai toàn bộ mã nguồn ứng dụng PickleVision Native iOS (iPhone / iPad) quay và phân tích trực tiếp thi đấu Pickleball bằng Computer Vision theo thời gian thực theo tài liệu đặc tả kiến trúc đã thống nhất.

Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision
Integrity mode: development

Tài liệu đặc tả kiến trúc chi tiết: C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md

## Requirements

### R1. Tổ chức và Điều phối Đội ngũ AI Agent
Thiết lập và vận hành đội ngũ AI Agent với các vai trò chuyên trách:
- Leader: Phân tích nhiệm vụ từ người dùng, lập kế hoạch chi tiết, phân chia công việc cho các thành viên và tạo thêm Agent phụ trợ nếu cần thiết.
- Athletic Coach: Đảm bảo toàn bộ logic ứng dụng tuân thủ chính xác luật thi đấu USA Pickleball (kích thước sân 13.41m x 6.10m, vạch bếp Non-Volley Zone cách lưới 2.13m mỗi bên, luật giao bóng, quy tắc vạch biên IN / vạch bếp FAULT khi giao bóng).
- Backend Coder: Triển khai các module Computer Vision, DLT Homography 3x3 với thư viện Accelerate LAPACK, Player Tracking (Vision Pose cổ chân + ByteTrack + Re-ID), Ball Tracking (parabolic curve fit, đo tốc độ km/h), phán quyết In/Out và Rally State Machine.
- Frontend Coder: Xây dựng toàn bộ giao diện người dùng SwiftUI và Metal Overlay (Top Status Bar, Bottom Player Metrics Bar, Minimap 2D Court, Replay Loupe).
- Tester: Xây dựng và thực thi bộ kiểm thử tự động độc lập (XCTest) cùng bộ mock data/sensor feed giả lập.
- Reviewer: Rà soát mã nguồn, kiểm tra tuân thủ kiến trúc, tối ưu hiệu năng thời gian thực và đảm bảo không có mã giả (placeholder).

### R2. Thu nhận Camera & Xử lý Rung lắc (Camera & Stabilization)
- Thiết lập AVCaptureSession hỗ trợ 60fps / 120fps độ phân giải 1080p.
- Tích hợp Cinematic Extended Stabilization và thuật toán Homography Anchor Tracking để liên tục bù góc phối cảnh khi tripod bị rung nhẹ.

### R3. Hiệu chuẩn Sân Bán tự động (Court Calibration)
- Triển khai giải thuật Direct Linear Transformation (DLT) qua Accelerate LAPACK để tính toán ma trận Homography 3x3 ($H$), chuyển đổi qua lại giữa tọa độ pixel 2D và tọa độ thực tế trên sân (mét).
- Hỗ trợ giao diện chạm 4 góc sân để người dùng tinh chỉnh chốt góc.

### R4. Theo dõi Người chơi & Đo lường Vận động (Player Tracking)
- Nhận diện khớp cổ chân qua Apple Vision (`VNDetectHumanBodyPoseRequest`).
- Duy trì định danh cầu thủ (2 người đánh đơn hoặc 4 người đánh đôi) bằng ByteTrack + Kalman Filter kết hợp đặc trưng histogram màu áo khi che khuất hoặc cắt chéo.
- Ánh xạ vị trí tiếp đất qua ma trận $H$ để đo quãng đường di chuyển tức thời của từng pha bóng và tổng quãng đường cả trận, áp dụng bộ lọc nhiễu rung lắc (< 0.05m).

### R5. Theo dõi Bóng, Đo Tốc độ & Phán quyết In/Out
- Theo dõi bóng tốc độ cao bằng xử lý khung hình kết hợp xấp xỉ quỹ đạo parabol ($y = at^2 + bt + c$).
- Đo tốc độ bóng tức thời (km/h) theo khoảng cách di chuyển thực tế trên thời gian $\Delta t$.
- Phát hiện điểm chạm đất (Bounce) khi đổi chiều gia tốc thẳng đứng và ánh xạ tọa độ sân để phán quyết tự động theo luật USA Pickleball: chạm vạch biên/đáy là IN; pha giao bóng rơi trong bếp hoặc chạm vạch bếp là FAULT/OUT; pha bóng bình thường rơi trong bếp là IN.

### R6. Giao diện HUD Trực tiếp, Rally Engine & Xuất Video
- HUD trực tiếp chuyên nghiệp: Thanh trạng thái trên đỉnh (thời gian pha, số pha, lượt đổi hướng, trạng thái trận đấu), Court Minimap 2D nhìn từ trên cao ở cột phải, 4 thẻ chỉ số cầu thủ ở thanh đáy.
- Rally Engine quản lý trạng thái: `CHỜ GIAO BÓNG` -> `ĐANG ĐÁNH` -> `KẾT THÚC PHA`.
- Xuất 2 luồng video: Clean video gốc và Burn-in broadcast video gắn đầy đủ overlay đồ họa.

## Verification Resources
- Bộ kiểm thử tự động XCTest độc lập do Tester xây dựng cùng mock data/sensor feed giả lập (tọa độ các điểm mốc sân, chuỗi tọa độ khớp cổ chân giả lập, dữ liệu video frame, vector parabol bóng và sự kiện nảy) để kiểm tra toàn bộ pipeline thuật toán.

## Acceptance Criteria

### Tính Toàn vẹn & Kiến trúc Mã nguồn
- [ ] Toàn bộ cấu trúc thư mục và các file mã nguồn Swift/SwiftUI theo mục 8 của tài liệu đặc tả được khởi tạo đầy đủ tại `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision`.
- [ ] Không có file nào chứa TODO chưa giải quyết, mã stub rỗng hoặc giả lập không hoàn chỉnh cho các thuật toán cốt lõi.

### Kiểm thử Giải thuật Độc lập (XCTest)
- [ ] Test suite kiểm thử ma trận Homography DLT 3x3 (Accelerate LAPACK) chứng minh sai số chuyển đổi tọa độ điểm chuẩn dưới 0.02 mét.
- [ ] Test suite kiểm thử phán quyết In/Out tự động phản ánh chính xác 100% các tình huống luật USA Pickleball (giao bóng chạm vạch bếp -> FAULT; bóng chạm vạch biên -> IN; bóng ngoài vạch -> OUT).
- [ ] Test suite kiểm thử Rally Engine chuyển đổi trạng thái chính xác giữa Chờ giao bóng, Đang đánh và Kết thúc pha.
- [ ] 100% các bài test trong test suite chạy pass mà không có lỗi.
