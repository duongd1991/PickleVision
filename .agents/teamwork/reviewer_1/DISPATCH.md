## 2026-11-05T10:38:47Z

Bạn là Reviewer 1 trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Rà soát toàn diện mã nguồn, kiểm tra tuân thủ kiến trúc, đối chiếu luật thi đấu USA Pickleball, chạy kiểm thử tự động độc lập và đánh giá độ hoàn thiện thực tế của ứng dụng.

Thư mục làm việc quản lý của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\reviewer_1\
Thư mục dự án: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision

Các tài liệu bắt buộc đọc:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PROJECT.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\TEST_READY.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\coach_survey\coach_rules_report.md

Phạm vi rà soát:
1. Rà soát cấu trúc thư mục và toàn bộ 19 file mã nguồn Swift:
   - `App/PickleVisionApp.swift`
   - `Models/`: CourtModel.swift, PlayerTrack.swift, RallyTelemetry.swift
   - `Core/Camera/`: CameraManager.swift, VideoStabilizer.swift
   - `Core/Vision/`: CourtCalibrationService.swift, PlayerTrackerService.swift, BallTrackerService.swift, PickleballCVCoordinator.swift
   - `Core/Engine/`: RallyEngine.swift, VideoExportEngine.swift
   - `UI/Live/`: LiveMatchContainerView.swift, CameraPreviewView.swift, TopStatusBarView.swift, CourtMiniMapView.swift, PlayerMetricsBarView.swift
   - `UI/Review/`: InstantReplayVARView.swift, MatchSummaryReportView.swift
   - `Tests/PickleVisionTests/`: 7 test files và `Package.swift`.
2. Kiểm tra tuân thủ tuyệt đối quy tắc luật USA Pickleball:
   - Kích thước sân 13.4112m x 6.096m, vạch bếp 2.1336m.
   - Khi giao bóng: chạm vạch bếp hoặc rơi vào bếp là FAULT/OUT. Chạm vạch biên/đáy là IN.
   - Khi pha bóng sống: rơi vào bếp là IN. Chạm vạch biên/đáy là IN.
   - Two-Bounce Rule và Kitchen Volley Fault.
3. Chạy kiểm thử độc lập:
   - Chạy lệnh `python PickleVision\test_runner.py` để kiểm tra kết quả pass/fail thực tế.
4. Kiểm tra tính toàn vẹn mã nguồn:
   - Quét tìm xem có TODO, FIXME, STUB hay placeholder nào không.
5. Đưa ra phán quyết rõ ràng:
   - `APPROVE` hoặc `REQUEST_CHANGES` (kèm chi tiết nếu có).

Ghi báo cáo review chi tiết vào `handoff.md` tại thư mục làm việc của bạn và dùng `send_message` thông báo phán quyết cho Orchestrator.
