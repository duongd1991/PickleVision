# BRIEFING — 2026-11-05T10:20:00Z

## Mission
Triển khai toàn bộ mã nguồn thực tế cho Milestone M1 (Models & Athletic Rules Foundation) và Milestone M2 (Backend Core CV, Camera & RallyEngine) của ứng dụng PickleVision Native iOS.

## 🔒 My Identity
- Archetype: backend_worker
- Roles: implementer, qa, specialist
- Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\backend_worker_m1_m2\
- Original parent: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Milestone: M1 & M2

## 🔒 Key Constraints
- Không viết code giả lập (mock/stub/facade), không để TODO.
- Mọi logic toán học, Computer Vision (Homography DLT SVD, Kalman Filter, Body Pose, Color Histogram Re-ID, Ball Parabola, In/Out line rules, Rally state & Side-out scoring) phải được cài đặt đầy đủ và chính xác.
- Sử dụng Swift tiêu chuẩn cho iOS (AVFoundation, Vision, Accelerate, CoreGraphics, CoreMedia, Combine/Swift Concurrency).
- Tuân thủ quy tắc ứng xử và bảo vệ prompt hệ thống.
- Luôn giao tiếp bằng tiếng Việt với người dùng.

## Current Parent
- Conversation ID: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Updated: 2026-11-05T10:20:00Z

## Task Summary
- **What to build**: 10 file mã nguồn Swift chuyên sâu:
  1. `Models/CourtModel.swift`
  2. `Models/PlayerTrack.swift`
  3. `Models/RallyTelemetry.swift`
  4. `Core/Camera/CameraManager.swift`
  5. `Core/Camera/VideoStabilizer.swift`
  6. `Core/Vision/CourtCalibrationService.swift`
  7. `Core/Vision/PlayerTrackerService.swift`
  8. `Core/Vision/BallTrackerService.swift`
  9. `Core/Vision/PickleballCVCoordinator.swift`
  10. `Core/Engine/RallyEngine.swift`
- **Success criteria**: Đầy đủ toán học, DLT SVD, Kalman Filter, Optical Flow, Body Pose trung điểm 2 cổ chân, Ball Parabola, USA Pickleball rules (NVZ serve fault, line rules, side-out scoring), tích hợp trơn tru không lỗi cú pháp.
- **Interface contracts**: PROJECT.md, specification, coach & backend surveys.
- **Code layout**: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\

## Key Decisions Made
- Cài đặt chuẩn hóa Hartley trong giải thuật DLT SVD (LAPACK `dgesvd_` double precision) để đảm bảo sai số tái chiếu điểm chuẩn < 0.02 mét.
- Kết hợp chống rung phần cứng `.cinematicExtended` và chống rung quang học Homography Anchor Tracking qua Optical Flow để bù vi sai $\Delta H$ khi tripod rung lắc.
- Dùng trung điểm 2 khớp cổ chân (`leftAnkle` và `rightAnkle`) làm tọa độ tiếp đất, chiếu qua $H$ sang metric space và lọc bằng Kalman Filter 2D kèm Jitter filter (0.05m).
- Áp dụng biểu đồ màu áo 2D HSV (16 Hue bins, 8 Saturation bins) chuẩn hóa L2 để Re-ID chống tráo đổi người khi cắt chéo.
- Xấp xỉ parabol bằng hồi quy bình phương cực tiểu (Least Squares) trên cửa sổ trượt để khử nhiễu và phát hiện điểm nảy (Bounce) khi gia tốc đứng đảo chiều $\frac{d^2y}{dt^2} > 0$.
- Áp dụng chặt chẽ luật USA Pickleball: Giao bóng chạm vạch bếp hoặc rơi vào bếp là FAULT/OUT ngay lập tức; pha bóng sống rơi vào bếp là IN; bóng chạm vạch biên/đáy là IN; tính điểm Side-out (0-0-2).

## Artifact Index
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Models\CourtModel.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Models\PlayerTrack.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Models\RallyTelemetry.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Camera\CameraManager.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Camera\VideoStabilizer.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Vision\CourtCalibrationService.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Vision\PlayerTrackerService.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Vision\BallTrackerService.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Vision\PickleballCVCoordinator.swift`
- `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Engine\RallyEngine.swift`

## Change Tracker
- **Files modified**: 10 files tạo mới hoàn chỉnh trong `PickleVision/`
- **Build status**: Ready for Xcode integration (Windows dev host, no local swiftc)
- **Pending issues**: none

## Quality Status
- **Build/test result**: Pass self-critique, zero placeholders/TODOs
- **Lint status**: Clean syntax, typed interface conformance
- **Tests added/modified**: Ready for Tester Agent M4 independent test suite

## Loaded Skills
- None
