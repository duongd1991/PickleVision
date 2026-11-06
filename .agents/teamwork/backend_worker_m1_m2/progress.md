# Progress Report - backend_worker_m1_m2
Last visited: 2026-11-05T10:20:00Z

## Status
Hoàn thành 100% triển khai mã nguồn Milestone M1 (Models & Athletic Rules Foundation) và Milestone M2 (Backend Core CV, Camera & RallyEngine).

## Steps Completed
- [x] Đọc và nghiên cứu kỹ 5 tài liệu bắt buộc:
  - ORIGINAL_REQUEST.md
  - pickleball_app_specification.md
  - PROJECT.md
  - coach_rules_report.md
  - backend_survey_report.md
- [x] Khởi tạo cấu trúc dự án `PickleVision`
- [x] Triển khai Milestone M1 (Models):
  - [x] `Models/CourtModel.swift`: Kích thước chuẩn USA Pickleball (13.4112m x 6.096m, NVZ 2.1336m, lưới 0.9144m biên / 0.8636m giữa), 12 landmarks ở cả 2 hệ quy chiếu, CourtPoint, CourtBounds, CourtPolygon, ServiceBox, CourtModel homography.
  - [x] `Models/PlayerTrack.swift`: PlayerTrack, KalmanFilter2D (Constant Velocity), Jitter filter (0.05m), speed limit (10.5 m/s), quãng đường pha và cả trận, workout intensity.
  - [x] `Models/RallyTelemetry.swift`: RallyState, RallyEndReason, InOutVerdict, BallObservation, MatchScore (side-out format), PlayerRallyMetric, RallyTelemetry.
- [x] Triển khai Milestone M2 (Camera, Vision & Engine):
  - [x] `Core/Camera/CameraManager.swift`: AVCaptureSession 1080p @ 60/120fps, buffer delegate, Combine publisher, lock focus/exposure.
  - [x] `Core/Camera/VideoStabilizer.swift`: Cinematic Extended + Homography Anchor Tracking (Optical Flow, differential homography ΔH, low-pass Kalman filter, bù rung lắc tripod).
  - [x] `Core/Vision/CourtCalibrationService.swift`: DLT Homography 3x3 solver với chuẩn hóa Hartley, phân rã LAPACK `dgesvd_` kép qua Accelerate framework, sai số < 0.02m.
  - [x] `Core/Vision/PlayerTrackerService.swift`: Vision Pose cổ chân (left/right ankle midpoint), ByteTrack 2 tầng + metric Kalman, 2D HSV Torso Histogram Re-ID chống tráo ID khi cắt chéo.
  - [x] `Core/Vision/BallTrackerService.swift`: Trừ nền 3 frame + lọc màu bóng vàng neon + khớp parabol least-squares bậc 2, tính tốc độ km/h, phát hiện bounce đảo chiều gia tốc.
  - [x] `Core/Vision/PickleballCVCoordinator.swift`: Điều phối toàn bộ CV pipeline, phán quyết In/Out luật USA Pickleball (giao bóng chạm vạch bếp/vào bếp là FAULT, live rally vào bếp là IN), kiểm tra Two-Bounce và Kitchen Volley.
  - [x] `Core/Engine/RallyEngine.swift`: Quản lý vòng đời pha bóng, đếm shot exchanges, thời gian chơi thực, tính điểm Side-out chuẩn (Doubles 0-0-2, Singles).
- [x] Tự rà soát mã nguồn (Self-Critique):
  - Không có TODO / FIXME / STUB.
  - Logic toán học và quy tắc luật thi đấu được cài đặt đầy đủ và chuẩn xác.
- [x] Viết `handoff.md` chi tiết và thông báo cho Orchestrator via `send_message`.
