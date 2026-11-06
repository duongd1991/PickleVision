## 2026-11-05T10:51:57Z
Bạn là Remediation Worker trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Khắc phục triệt để toàn bộ 7 lỗi và cải tiến kỹ thuật do Reviewer 1, Challenger 1 và Challenger 2 phát hiện tại Iteration 4.

Thư mục làm việc quản lý của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\remediation_worker_iter5\
Thư mục dự án: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision

Các tài liệu bắt buộc đọc kỹ:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PROJECT.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\orchestrator\GATE_STATUS.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\reviewer_1\handoff.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\challenger_1\handoff.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\challenger_2\handoff.md

CHI TIẾT 7 HẠNG MỤC CẦN SỬA ĐỔI:
1. `Models/CourtModel.swift` (dòng 206-213):
   - Sửa logic ô giao bóng chéo sân `ServiceBox.diagonalTarget`:
     * `nearRight` ($X \ge 3.048$) -> phải chéo sang `farLeft` ($X \le 3.048$).
     * `nearLeft` ($X \le 3.048$) -> phải chéo sang `farRight` ($X \ge 3.048$).
     * `farRight` -> `nearLeft`.
     * `farLeft` -> `nearRight`.
2. `Core/Engine/VideoExportEngine.swift`:
   - Bổ sung `import UIKit` và `import SwiftUI` ở đầu file để hỗ trợ `UIColor`, `UIFont`, `Path`.
3. `Core/Vision/PickleballCVCoordinator.swift`:
   - Bổ sung logic tăng số lượt đổi hướng: Khi bóng vượt qua mặt phẳng lưới ($Y = 6.7056$m), gọi `rallyEngine.registerShotExchange()`.
   - Trong `evaluateBounceVerdict`: Bổ sung kiểm tra `targetServiceBox` cho cả trường hợp phát bóng sang sân gần (`isTargetFarCourt == false`), nếu rơi sai ô giao bóng sân gần thì trả về `outOfBound`.
   - Trong `checkKitchenVolleyFault`: Thêm điều kiện khoảng cách bóng với cầu thủ (khoảng cách $\le 1.5$m) mới phạt lỗi giẫm bếp khi vô-lê, tránh phạt oan cầu thủ không chạm bóng.
4. `Core/Vision/BallTrackerService.swift`:
   - Chuẩn hóa quy ước trục $Y$ camera (hướng xuống đất) và trục vật lý (Cartesian hướng lên trời) khi kiểm tra `wasMovingDownward` và đổi chiều gia tốc, đảm bảo thuật toán nhận diện nảy (Bounce) hoạt động chính xác trong cả 2 hệ quy chiếu.
5. `Models/PlayerTrack.swift`:
   - Pre-Gating cho Kalman Filter: Kiểm tra vận tốc bước nhảy $\Delta d / \Delta t \le 10.5$ m/s TRƯỚC khi gọi `kalmanFilter.update()`. Nếu là bước nhảy lỗi (teleportation glitch), bỏ qua bước cập nhật đo lường (chỉ predict hoặc giữ nguyên vị trí), ngăn chặn triệt để hiện tượng tê liệt bám vết (Post-Glitch Tracking Paralysis).
   - Bộ lọc Deadband / Jitter: Khi $\Delta d < 0.05$m, khóa vị trí và triệt tiêu vận tốc ngoại suy của Kalman để loại trừ hiện tượng Velocity Overshoot gây rò rỉ mét ảo khi cầu thủ đứng yên.
6. `Core/Vision/CourtCalibrationService.swift`:
   - Mở rộng hỗ trợ DLT 6 điểm (4 góc sân + 2 điểm chốt vạch bếp) bên cạnh DLT 4 điểm, đảm bảo sai số tái chiếu RMSE luôn dưới 0.02m ngay cả khi tripod đặt ở độ cao thấp $1.8$m dưới góc nghiêng lớn và nhiễu sub-pixel.
7. `PickleVision/test_runner.py` và các test file trong `Tests/PickleVisionTests/`:
   - Cập nhật test_runner.py đồng bộ với các sửa đổi trên:
     * Cập nhật test case kiểm tra `diagonalTarget` (nearRight -> farLeft).
     * Bổ sung test case kiểm tra giao bóng sai ô sân gần trả về OUT.
     * Cập nhật mô hình PlayerTrack trong test runner với Pre-Gating và kiểm tra không bị tê liệt bám vết sau glitch.
     * Bổ sung test DLT 6 điểm.
   - Chạy `python PickleVision\test_runner.py` để chứng minh 100% test pass.


## 2026-11-05T11:07:38Z
**Context**: Kiểm tra tiến độ khắc phục 7 hạng mục Iteration 5.
**Content**: Orchestrator nhận thấy bạn đã hoàn thành việc chỉnh sửa các file mã nguồn cốt lõi (CourtModel, VideoExportEngine, PlayerTrack, PickleballCVCoordinator) và test_runner.py. Bạn đã chạy kiểm thử và hoàn thành báo cáo `handoff.md` chưa?
**Action**: Cập nhật tiến độ hoặc gửi báo cáo handoff.md về cho Orchestrator nếu đã hoàn tất.
