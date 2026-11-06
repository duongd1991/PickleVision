## 2026-11-05T10:22:25Z
Bạn là Frontend Coder trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Triển khai toàn bộ mã nguồn thực tế cho Milestone M3 (Frontend UI, Metal HUD & Video Export Engine).

Thư mục làm việc quản lý của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\frontend_worker_m3\
Thư mục dự án đích: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision

Các tài liệu bắt buộc đọc kỹ trước khi viết code:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PROJECT.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\coach_survey\coach_rules_report.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\frontend_survey\frontend_testing_report.md
- Các file Backend đã hoàn thiện: `PickleVision/Models/` (CourtModel.swift, PlayerTrack.swift, RallyTelemetry.swift) và `PickleVision/Core/` (CameraManager.swift, VideoStabilizer.swift, CourtCalibrationService.swift, PlayerTrackerService.swift, BallTrackerService.swift, PickleballCVCoordinator.swift, RallyEngine.swift).

Phạm vi file bạn SỞ HỮU ĐỘC QUYỀN (tạo mới và triển khai toàn bộ, KHÔNG viết stub, KHÔNG để TODO):
1. `App/PickleVisionApp.swift`:
   - `@main struct PickleVisionApp: App`.
   - Khởi tạo `PickleballCVCoordinator` và `RallyEngine` làm `@StateObject` hoặc Environment Objects.
   - Root view: `LiveMatchContainerView`.
2. `UI/Live/LiveMatchContainerView.swift`:
   - Màn hình chính điều phối trực tiếp (Live Match).
   - Ghép nối các lớp: `CameraPreviewView` ở lớp nền, lớp phủ Metal HUD vector (vệt bóng bay vàng neon, thẻ tên nổi trên đầu cầu thủ, vòng tròn định vị dưới chân cầu thủ trên mặt sân thực), `TopStatusBarView` ở mép trên, `CourtMiniMapView` ở cột phải (170x260 pt), `PlayerMetricsBarView` ở mép đáy.
   - Sheet hoặc overlay kích hoạt `InstantReplayVARView` khi có sự kiện nảy bóng cần xem lại VAR hoặc khi bấm nút VAR, và `MatchSummaryReportView` khi kết thúc trận đấu.
3. `UI/Live/CameraPreviewView.swift`:
   - Hiển thị luồng video camera độ phân giải cao, sử dụng `UIViewRepresentable` bọc `MTKView` (MetalKit) với cơ chế zero-copy texture cache (`CVMetalTextureCache`) và BT.709 color conversion Metal shaders.
   - Hỗ trợ cử chỉ chạm 4 góc sân để người dùng tinh chỉnh 4 chốt góc sân (Calibration Touch Mode).
4. `UI/Live/TopStatusBarView.swift`:
   - Thanh trạng thái chuyên nghiệp dạng kính mờ (Ultra-thin material / blur background) ở mép trên:
     * Thời gian pha cầu (ví dụ: `00:14.3`)
     * Pha số (ví dụ: `Pha 1`)
     * Lượt cầu đổi hướng (`15`)
     * Thời gian chơi thực (`00:14.4`)
     * Trạng thái trận đấu: `CHỜ GIAO BÓNG` (Xanh dương) / `ĐANG ĐÁNH` (Xanh lá) / `KẾT THÚC PHA` (Cam/Đỏ).
5. `UI/Live/CourtMiniMapView.swift`:
   - Bản đồ sân 2D nhìn từ trên cao (Top-down 2D court view) đặt ở cột phải.
   - Vẽ chính xác tỷ lệ sân chuẩn USA Pickleball (13.4112m x 6.096m) gồm: 2 vạch đáy, 2 vạch biên, vạch giữa, 2 vạch bếp NVZ (2.1336m từ lưới mỗi bên), vùng bếp tô màu phân biệt.
   - Hiển thị chấm tròn 4 cầu thủ theo tọa độ mét thời gian thực kèm vệt di chuyển (tail).
   - Hiển thị đường bay bóng và điểm nảy (Bounce marker) với nhãn IN/OUT trực quan.
6. `UI/Live/PlayerMetricsBarView.swift`:
   - Thanh đáy hiển thị 4 thẻ cầu thủ (ví dụ: Tú, Cường, Nam, Thành):
     * Quãng đường pha này (m) (ví dụ: `18.5 m`)
     * Tổng quãng đường cả trận (m) (ví dụ: `420 m`)
     * Thanh đo cường độ vận động / tốc độ tức thời.
     * Tích hợp Scrubber phát lại video, nút tạm dừng, nút kích hoạt VAR.
7. `UI/Review/InstantReplayVARView.swift`:
   - Giao diện xem lại VAR / Slow-motion cận cảnh điểm chạm bóng.
   - Vòng tròn zoom cận cảnh (Magnifying Loupe 4x) tại điểm tiếp xúc sân với vạch:
     * Chạm vạch biên / vạch đáy / vạch giữa khi giao bóng -> Viền & Nhãn IN (Xanh lá).
     * Chạm vạch bếp hoặc rơi vào bếp khi giao bóng -> Viền & Nhãn FAULT / OUT (Đỏ).
     * Rơi vào bếp trong pha bóng bình thường -> Viền & Nhãn IN (Xanh lá).
   - Hỗ trợ thanh trượt tua chậm (Slow-motion 5s clip).
8. `UI/Review/MatchSummaryReportView.swift`:
   - Báo cáo tổng kết sau trận đấu:
     * Bản đồ nhiệt di chuyển của từng cầu thủ (2D Heatmap Kernel Density Estimation trên mặt sân).
     * Tốc độ bóng lớn nhất (Peak Speed km/h).
     * Tổng số mét di chuyển của cả 4 cầu thủ và so sánh thể lực.
     * Tỷ lệ kiểm soát sân (Court Control %).
     * Nút xuất báo cáo Infographic / PDF và xuất video.
9. `Core/Engine/VideoExportEngine.swift`:
   - Xuất 2 luồng video chất lượng cao bằng `AVAssetWriter`:
     1. Clean Video Feed: Video gốc không gắn HUD overlay.
     2. Burn-in Broadcast Video: Video truyền hình thể thao hoàn chỉnh ghép cứng toàn bộ HUD, Minimap và thông số đồ họa thời gian thực.
   - Hỗ trợ cả 2 định dạng: 16:9 ngang (Broadcast / YouTube) và 9:16 dọc (Reels / TikTok với Smart Center Dynamic Crop).
