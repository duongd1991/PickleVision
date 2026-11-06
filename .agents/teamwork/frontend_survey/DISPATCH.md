## 2026-11-05T10:02:09Z
[Message] timestamp=2026-11-05T10:02:09Z sender=c4a80aac-c6f3-45ce-a5dc-a550acba35ac priority=MESSAGE_PRIORITY_HIGH content=Bạn là Frontend & Testing Architect Explorer trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Khảo sát và thiết kế chi tiết toàn bộ kiến trúc Giao diện người dùng SwiftUI + Metal HUD Overlay, Video Export Engine, cùng với chiến lược Kiểm thử tự động độc lập (XCTest) với Mock Data Feeds.

Thư mục làm việc của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\frontend_survey\
Các tài liệu bắt buộc đọc:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md

Yêu cầu nội dung báo cáo khảo sát kỹ thuật Frontend & Testing (frontend_testing_report.md):
1. Thiết kế Giao diện Trực tiếp (Live HUD Overlay):
   - `LiveMatchContainerView.swift`: Màn hình chứa video feed và các lớp overlay HUD.
   - `CameraPreviewView.swift`: Tích hợp AVCaptureVideoPreviewLayer hoặc Metal rendering buffer.
   - `TopStatusBarView.swift`: Hiển thị Thời gian pha (00:14.3), Pha số (Pha 1), Lượt đổi hướng (15), Thời gian chơi thực (00:14.4), Trạng thái trực tiếp (ĐANG ĐÁNH - Xanh lá).
   - `CourtMiniMapView.swift`: Bản đồ sân 2D nhìn từ trên cao (Top-down 2D court view) ở cột phải, vẽ vị trí 4 cầu thủ theo thời gian thực kèm đuôi di chuyển, đường bay bóng và điểm nảy.
   - `PlayerMetricsBarView.swift`: Thanh đáy gồm 4 thẻ cầu thủ hiển thị quãng đường cả trận, quãng đường pha này, thanh cường độ vận động, kèm scrubber phát lại.
2. Thiết kế Giao diện Xem lại & Báo cáo (Review & Export UI):
   - `InstantReplayVARView.swift`: Vòng tròn phóng đại (Magnifying Loupe) tại điểm tiếp xúc sân với nhãn IN (Xanh lá) hoặc OUT (Đỏ), hỗ trợ slow-motion clip 5s.
   - `MatchSummaryReportView.swift`: Thống kê tổng kết, heatmap di chuyển, peak speed, tỷ lệ kiểm soát sân.
3. Kỹ thuật Xuất Video (Video Export Engine):
   - `VideoExportEngine.swift`: Cơ chế xuất 2 luồng: Clean Video gốc và Burn-in broadcast video (sử dụng AVAssetWriter ghép Metal Overlay đồ họa, tỷ lệ 16:9 ngang và 9:16 dọc).
4. Thiết kế Bộ kiểm thử Tự động Độc lập (Independent XCTest Suite):
   - Thiết kế các Test Cases và Mock Data Feeds độc lập (không phụ thuộc vào camera thật):
     a. DLT Homography Test: Mock 4 góc sân pixel và tọa độ mét thực tế, tính $H$, kiểm tra sai số chuyển đổi điểm chuẩn < 0.02 mét.
     b. In/Out Rules Test: Kiểm tra đầy đủ các tình huống:
        - Giao bóng chạm vạch bếp (Kitchen Line) -> FAULT.
        - Giao bóng rơi trong khu vực bếp -> FAULT.
        - Giao bóng chéo sân chạm vạch biên/đáy/giữa -> IN.
        - Pha bóng bình thường rơi trong bếp -> IN.
        - Pha bóng bình thường chạm vạch biên/đáy -> IN.
        - Pha bóng bình thường rơi ngoài sân -> OUT.
     c. RallyEngine State Machine Test: Chuyển đổi trạng thái WAITING_FOR_SERVE -> IN_PLAY -> RALLY_END, tính toán quãng đường tích lũy, số lượt đổi hướng.
     d. Player Distance & Jitter Filter Test: Kiểm tra lọc nhiễu < 0.05m và cộng dồn quãng đường chính xác.
     e. Ball Parabola & Speed Calculation Test: Vector nảy và tính km/h.
5. Yêu cầu bàn giao:
   - Ghi báo cáo khảo sát kỹ thuật vào `frontend_testing_report.md` tại thư mục làm việc của bạn.
   - Tạo `handoff.md` tóm tắt toàn bộ cấu trúc view, state binding, test runner strategy cho orchestrator.
   - Dùng send_message gửi thông báo sau khi hoàn thành.
