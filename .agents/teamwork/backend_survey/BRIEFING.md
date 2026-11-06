# BRIEFING — 2026-11-05T10:07:30Z

## Mission
Khảo sát và thiết kế chi tiết toàn bộ kiến trúc Backend Computer Vision, các giải thuật toán học và mô hình dữ liệu cho ứng dụng PickleVision Native iOS.

## 🔒 My Identity
- Archetype: explorer
- Roles: Backend CV Architect Explorer
- Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\backend_survey\
- Original parent: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Milestone: Backend CV & Mathematical Architecture Survey

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Phản hồi bằng tiếng Việt, giữ nguyên thuật ngữ kỹ thuật, tên biến, cấu trúc code Swift và công thức toán học
- Lưu trữ kết quả chính tại backend_survey_report.md và handoff.md trong thư mục làm việc
- Gửi thông báo hoàn thành qua send_message tới parent

## Current Parent
- Conversation ID: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Updated: 2026-11-05T10:07:30Z

## Investigation State
- **Explored paths**:
  - `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md`
  - `C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md`
- **Key findings**:
  - Cấu hình AVCaptureSession: 1080p @ 60/120fps (NV12 format) kết hợp Cinematic Extended và Homography Anchor Tracking (Optical Flow bù góc vi sai $\Delta H$).
  - Thuật toán DLT Homography 3x3: Bắt buộc chuẩn hóa Hartley để đạt sai số $< 0.003\text{m}$ (đáp ứng tiêu chuẩn $< 2\text{cm}$), phân rã SVD giải nghiệm qua LAPACK `dgesvd_` trong Accelerate framework.
  - Player Tracking: Apple Vision pose nhận diện trung điểm 2 cổ chân, Kalman Filter trong không gian mét $(X, Y)$ kết hợp ByteTrack 2 tầng và biểu đồ màu áo 2D HSV Histogram (Re-ID) để triệt tiêu hiện tượng tráo ID khi cắt chéo; bộ lọc rung $\Delta d < 0.05\text{m}$.
  - Ball CV: Bắt bóng tốc độ cao qua trừ nền 3 frame + lọc màu vàng neon + TrackNet; xấp xỉ quỹ đạo Parabol $y(t) = at^2 + bt + c$; vận tốc $v = \frac{\Delta d}{\Delta t} \times 3.6$ km/h; phát hiện điểm nảy $d^2y/dt^2 > 0$ tại $Z \approx 0$; phán quyết theo luật USA Pickleball (giao bóng chạm vạch bếp là FAULT/OUT; bóng thường vào bếp là IN; chạm vạch biên là IN).
  - Kiến trúc Data Models & Máy trạng thái: Hoàn thiện thiết kế `CourtModel.swift`, `PlayerTrack.swift`, `RallyTelemetry.swift`, `RallyEngine.swift` và `PickleballCVCoordinator.swift`.
- **Unexplored areas**: Không còn (Hoàn thành 100% khảo sát và thiết kế kỹ thuật).

## Key Decisions Made
- Lựa chọn chuẩn hóa Hartley kết hợp phân rã SVD LAPACK `dgesvd_` để đảm bảo độ chính xác chuyển đổi tọa độ điểm chuẩn $< 2\text{cm}$.
- Chạy Kalman Filter trên mặt phẳng tọa độ sân thực tế $(X,Y)$ thay vì không gian pixel để tránh phi tuyến tính do góc phối cảnh camera.
- Tách biệt rõ ràng luật phán quyết giữa pha Giao bóng (Serve) và Đang đánh (Live Rally) đối với khu vực Non-Volley Zone (Bếp).

## Artifact Index
- DISPATCH.md — Chỉ thị nhiệm vụ ban đầu
- BRIEFING.md — Bộ nhớ ngữ cảnh làm việc
- progress.md — Nhật ký nhịp tim tiến độ
- backend_survey_report.md — Báo cáo khảo sát kỹ thuật Backend CV chuyên sâu (6 phần chi tiết)
- handoff.md — Báo cáo bàn giao 5 thành phần cho Orchestrator
