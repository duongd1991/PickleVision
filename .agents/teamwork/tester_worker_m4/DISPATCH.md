## 2026-11-05T10:22:47Z
Bạn là Tester trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Xây dựng và thực thi bộ kiểm thử tự động độc lập (XCTest Suite) cùng bộ mock data/sensor feed giả lập cho Milestone M4, xác minh toàn bộ các giải thuật và quy tắc của ứng dụng PickleVision.

Thư mục làm việc quản lý của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\tester_worker_m4\
Thư mục dự án đích: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision

Các tài liệu bắt buộc đọc kỹ:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PROJECT.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\coach_survey\coach_rules_report.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\backend_survey\backend_survey_report.md
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\frontend_survey\frontend_testing_report.md
- Toàn bộ mã nguồn Backend đã hoàn thiện: `PickleVision/Models/` và `PickleVision/Core/`.

Phạm vi file bạn SỞ HỮU ĐỘC QUYỀN (tạo mới và triển khai toàn bộ, KHÔNG viết stub, KHÔNG để TODO):
1. `Package.swift`:
   - Cấu hình Swift Package Manager (SPM) độc lập để biên dịch và chạy `swift test` trên mọi môi trường hỗ trợ Swift (bao gồm cả command line / cross-platform / Windows Swift toolchain nếu có, hoặc tạo test runner Swift thuần).
2. `Tests/PickleVisionTests/MockDataFeeds.swift`:
   - Bộ sinh dữ liệu giả lập chuẩn xác:
     * Tọa độ các điểm mốc sân chuẩn (pixel 2D và mét thực tế 13.4112m x 6.096m).
     * Chuỗi tọa độ khớp cổ chân giả lập (bước chạy, đứng yên, cắt chéo đổi sân).
     * Vector quỹ đạo bóng bay parabol và chuỗi các điểm nảy (Bounce events).
     * Mock CVPixelBuffer & Vision observations.
3. `Tests/PickleVisionTests/DLTHomographyTests.swift`:
   - Kiểm thử giải thuật Direct Linear Transformation (DLT) 3x3 qua Accelerate LAPACK SVD `dgesvd_` với chuẩn hóa Hartley.
   - CHỨNG MINH THỰC NGHIỆM: Sai số chuyển đổi tọa độ điểm chuẩn (Reprojection Error RMSE) tuyệt đối dưới 0.02 mét (< 2cm).
4. `Tests/PickleVisionTests/InOutRulesTests.swift`:
   - Kiểm thử 100% các tình huống luật USA Pickleball:
     * Giao bóng chạm vạch bếp (Kitchen Line) -> FAULT (OUT ngay lập tức!).
     * Giao bóng rơi trong khu vực bếp -> FAULT (OUT).
     * Giao bóng chéo sân chạm mép vạch biên, vạch đáy, vạch giữa -> IN.
     * Pha bóng bình thường rơi trong khu vực bếp -> IN (Hợp lệ).
     * Pha bóng bình thường chạm mép vạch biên hoặc vạch đáy -> IN.
     * Pha bóng bình thường rơi ngoài vạch biên/đáy -> OUT.
     * Kiểm tra Two-Bounce Rule và Kitchen Volley Fault.
5. `Tests/PickleVisionTests/RallyEngineTests.swift`:
   - Kiểm thử Rally Engine chuyển đổi chính xác giữa các trạng thái: `WAITING_FOR_SERVE` -> `SERVE_IN_FLIGHT` -> `IN_PLAY` -> `RALLY_END`.
   - Kiểm thử đếm số lượt đổi hướng (Shot exchanges), tính thời gian chơi và tính điểm Side-out chuẩn.
6. `Tests/PickleVisionTests/PlayerDistanceFilterTests.swift`:
   - Kiểm thử bộ lọc rung lắc Jitter: Bỏ qua biến thiên $\Delta d < 0.05$ mét.
   - Kiểm thử tích lũy quãng đường di chuyển tức thời và tổng quãng đường cả trận cho từng cầu thủ.
7. `Tests/PickleVisionTests/BallParabolaSpeedTests.swift`:
   - Kiểm thử xấp xỉ parabol $y = at^2 + bt + c$, phát hiện điểm nảy đổi chiều gia tốc, và tính tốc độ chính xác ra km/h.
8. `Tests/PickleVisionTests/FullPipelineIntegrationTests.swift`:
   - Tích hợp toàn diện pipeline từ hiệu chuẩn sân, tracking cầu thủ, tracking bóng, phán quyết và rally state.

YÊU CẦU THỰC THI & CHỨNG MINH:
- Sau khi viết mã test, bạn hãy chạy thực thi kiểm thử hoặc tạo script thực thi chạy test suite. Nếu môi trường có swift compiler (`swift test`), hãy chạy trực tiếp. Nếu không có swift binary trên Windows host, hãy tạo một test runner script/verifier độc lập chạy qua toàn bộ test cases logic để chứng minh 100% test pass.
- Báo cáo số lượng test cases, kết quả pass/fail từng test suite.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Viết báo cáo `handoff.md` chi tiết trong thư mục của bạn và gửi `send_message` thông báo cho Orchestrator sau khi hoàn tất.


## 2026-11-05T10:36:19Z
[Message from parent c4a80aac-c6f3-45ce-a5dc-a550acba35ac]
Context: Kiểm tra tiến độ Milestone M4 (XCTest Suite & Verification).
Content: Orchestrator nhận thấy bạn đã hoàn thành các test suite trong `PickleVision/Tests/PickleVisionTests/` và tạo `test_runner.py`. Bạn đã chạy kiểm thử và hoàn thành báo cáo `handoff.md` chưa?
Action: Cập nhật tiến độ hoặc gửi báo cáo handoff.md về cho Orchestrator nếu đã hoàn tất.
