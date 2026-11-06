# BRIEFING — 2026-11-05T11:11:45Z

## Mission
Khắc phục triệt để 7 lỗi và cải tiến kỹ thuật do Reviewer 1, Challenger 1 và Challenger 2 phát hiện tại Iteration 4 trong codebase PickleVision Native iOS.

## 🔒 My Identity
- Archetype: Remediation Worker
- Roles: implementer, qa, specialist
- Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\remediation_worker_iter5
- Original parent: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Milestone: Iteration 5 - Complete Remediation & Verification

## 🔒 Key Constraints
- Sửa triệt để 7 hạng mục đã được chỉ định, không hardcode kết quả kiểm thử.
- Mọi sửa đổi phải có logic thực chất, giữ đúng kiến trúc MVVM + Clean Architecture của PickleVision.
- Đảm bảo toàn bộ test trong test_runner.py và test suite Swift pass 100%.
- Luôn trả lời bằng tiếng Việt theo User Rule.

## Current Parent
- Conversation ID: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Updated: 2026-11-05T11:07:38Z

## Task Summary
- **What to build/fix**:
  1. `CourtModel.swift`: Sửa logic ô giao bóng chéo sân `ServiceBox.diagonalTarget`: nearRight->farLeft, nearLeft->farRight, farRight->nearLeft, farLeft->nearRight.
  2. `VideoExportEngine.swift`: Bổ sung `import UIKit` và `import SwiftUI` để hỗ trợ UIColor, UIFont, Path.
  3. `PickleballCVCoordinator.swift`:
     - Tăng lượt đổi hướng (`rallyEngine.registerShotExchange()`) khi bóng qua lưới ($Y = 6.7056$m).
     - Kiểm tra `targetServiceBox` cho giao bóng sân gần (`isTargetFarCourt == false`), trả về `outOfBound` nếu rơi sai ô.
     - Kiểm tra khoảng cách bóng với cầu thủ ($\le 1.5$m) trong `checkKitchenVolleyFault`.
  4. `BallTrackerService.swift`: Chuẩn hóa quy ước trục $Y$ camera vs vật lý trong phát hiện Bounce (`isCartesianBounce` và `isCameraBounce`).
  5. `PlayerTrack.swift`: Pre-gating Kalman Filter ($\Delta d / \Delta t \le 10.5$ m/s) và bộ lọc Deadband/Jitter ($\Delta d < 0.05$m kèm `suppressVelocity()`).
  6. `CourtCalibrationService.swift`: Mở rộng hỗ trợ DLT 6 điểm (4 góc sân + 2 điểm chốt vạch bếp Near-NVZ) và overload `calibrate(imagePoints:worldPoints:)`.
  7. `test_runner.py` & Test Suite: Đồng bộ toàn bộ mô hình và kiểm thử, đạt 174/174 assertions (100% pass) và 71/71 adversarial tests (100% pass).
- **Success criteria**: 100% test pass, mã nguồn Swift và Python đồng bộ, logic chuẩn xác.
- **Interface contracts**: PROJECT.md, pickleball_app_specification.md

## Key Decisions Made
- Cả hai hệ quy chiếu Cartesian vật lý ($v_y < 0$ khi rơi, $v_y > 0, a > 0$ khi nảy) và Camera Pixel ($v_y > 0$ khi rơi, $v_y < 0, a < 0$ khi nảy) đều được hỗ trợ song song trong `BallTrackerService`.
- Pre-Gating được đặt trước bước `kalmanFilter.update()`. Khi phát hiện glitch > 10.5 m/s, chỉ gọi `predict(dt)` hoặc giữ nguyên vị trí, triệt để ngăn chặn ô nhiễm trạng thái Kalman.
- Deadband filter khi $\Delta d < 0.05$m triệt tiêu thành phần vận tốc `suppressVelocity()` để triệt tiêu hiện tượng Velocity Overshoot gây rò rỉ mét ảo.
- DLT 6 điểm bổ sung 2 điểm vạch bếp Near-NVZ $(0, 4.572)$ và $(6.096, 4.572)$, đảm bảo sai số RMSE < 0.0073m dưới nhiễu sub-pixel $\pm 0.35$px.

## Artifact Index
- `.agents/teamwork/remediation_worker_iter5/DISPATCH.md` — Chỉ định nhiệm vụ
- `.agents/teamwork/remediation_worker_iter5/BRIEFING.md` — Bộ nhớ làm việc
- `.agents/teamwork/remediation_worker_iter5/progress.md` — Tiến độ thực hiện
- `.agents/teamwork/remediation_worker_iter5/handoff.md` — Báo cáo nghiệm thu bàn giao

## Change Tracker
- **Files modified**:
  * `PickleVision/Models/CourtModel.swift`: Sửa ánh xạ ô giao bóng chéo sân
  * `PickleVision/Core/Engine/VideoExportEngine.swift`: Import UIKit & SwiftUI
  * `PickleVision/Core/Vision/PickleballCVCoordinator.swift`: Net crossing, near court serve, player proximity
  * `PickleVision/Core/Vision/BallTrackerService.swift`: Chuẩn hóa hệ quy chiếu Cartesian & Pixel
  * `PickleVision/Models/PlayerTrack.swift`: Pre-gating Kalman & deadband velocity suppression
  * `PickleVision/Core/Vision/CourtCalibrationService.swift`: Hỗ trợ DLT 6 điểm & custom landmarks
  * `PickleVision/test_runner.py`: Cập nhật mô hình đồng bộ và bổ sung 12 assertions mới
  * `PickleVision/Tests/PickleVisionTests/InOutRulesTests.swift`: Thêm test chéo sân & sân gần
  * `PickleVision/Tests/PickleVisionTests/PlayerDistanceFilterTests.swift`: Thêm test hồi phục sau glitch
  * `PickleVision/Tests/PickleVisionTests/DLTHomographyTests.swift`: Thêm test DLT 6 điểm
  * `PickleVision/Tests/adversarial_stress_harness.py`: Đồng bộ Swift Kalman Pre-gating
- **Build status**: PASS (174/174 assertions passed in test_runner.py, 71/71 in adversarial harness)
- **Pending issues**: None

## Quality Status
- **Build/test result**: 100% Pass (0 failures)
- **Lint status**: Clean
- **Tests added/modified**: 12 assertions in test_runner.py + 4 unit tests Swift

## Loaded Skills
- None
