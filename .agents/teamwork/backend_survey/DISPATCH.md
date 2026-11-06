## 2026-11-05T10:01:42Z

**From**: c4a80aac-c6f3-45ce-a5dc-a550acba35ac (parent orchestrator)
**Content**:
Bạn là Backend CV Architect Explorer trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Khảo sát và thiết kế chi tiết toàn bộ kiến trúc Backend Computer Vision, các giải thuật toán học và mô hình dữ liệu cho ứng dụng PickleVision.

Thư mục làm việc của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\backend_survey\
Các tài liệu bắt buộc đọc:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md

Yêu cầu nội dung báo cáo khảo sát kỹ thuật Backend (backend_survey_report.md):
1. Camera & Chống rung (Camera & Stabilization):
   - Cấu hình AVCaptureSession: 1080p @ 60fps / 120fps (sử dụng AVCaptureDevice.Format phù hợp).
   - Cinematic Extended Stabilization (`AVCaptureConnection.preferredVideoStabilizationMode = .cinematicExtended`).
   - Thuật toán Homography Anchor Tracking: Liên tục đối soát các điểm mốc vạch sân để bù góc ma trận phối cảnh $H$ khi tripod bị rung lắc.
2. Direct Linear Transformation (DLT) Homography 3x3:
   - Toán học ma trận Homography $H \in \mathbb{R}^{3 \times 3}$ ánh xạ tọa độ pixel $(u, v)$ sang tọa độ thực tế trên sân $(X, Y)$ (mét).
   - Triển khai thuật toán DLT giải hệ phương trình $Ah = 0$ bằng thư viện Apple `Accelerate` (LAPACK Singular Value Decomposition SVD `sgesvd_` / `dgesvd_` hoặc hệ phương trình tuyến tính `sgesv_`).
   - Độ chính xác yêu cầu: Sai số chuyển đổi tọa độ điểm chuẩn dưới 0.02 mét (< 2cm).
   - Cơ chế hiệu chuẩn 4 góc sân bán tự động (tinh chỉnh touch 4 góc).
3. Player Tracking & Vận động:
   - Sử dụng Apple Vision framework (`VNDetectHumanBodyPoseRequest`) nhận diện khớp cổ chân (leftAnkle, rightAnkle).
   - Tọa độ tiếp đất = trung điểm 2 cổ chân.
   - Thuật toán ByteTrack + Kalman Filter kết hợp trích xuất đặc trưng histogram màu áo (Re-ID) để duy trì định danh 2 hoặc 4 người chơi khi che khuất/giao cắt.
   - Ánh xạ tọa độ tiếp đất qua ma trận $H$ ra tọa độ mét trên sân.
   - Đo quãng đường tức thời: $\Delta d = \sqrt{(X_t - X_{t-1})^2 + (Y_t - Y_{t-1})^2}$, áp dụng bộ lọc rung nhiễu (jitter filter $\Delta d < 0.05$m).
   - Tính toán song song: Quãng đường pha bóng hiện tại và tổng quãng đường cả trận của từng cầu thủ.
4. Ball Tracking, Đo tốc độ & Phán quyết In/Out:
   - Xử lý khung hình bắt bóng nhanh (kết hợp trừ nền / color threshold / CoreML TrackNet).
   - Xấp xỉ quỹ đạo bóng bằng phương trình parabol: $y(t) = at^2 + bt + c$.
   - Tính toán tốc độ tức thời: $v = \frac{\Delta d}{\Delta t} \times 3.6$ (km/h).
   - Phát hiện điểm nảy (Bounce): Điểm đảo chiều gia tốc thẳng đứng ($d^2y/dt^2 > 0$) tại mặt sân ($Z \approx 0$).
   - Thuật toán phán quyết In/Out tự động theo chuẩn USA Pickleball: Giao bóng chạm vạch bếp hoặc vào bếp -> FAULT (OUT); pha bóng thường vào bếp -> IN; chạm vạch biên/đáy -> IN; ra ngoài -> OUT.
5. Máy trạng thái Rally & Mô hình dữ liệu (Models & RallyEngine):
   - Thiết kế các model: `CourtModel.swift`, `PlayerTrack.swift`, `RallyTelemetry.swift`.
   - Thiết kế `RallyEngine.swift` và `PickleballCVCoordinator.swift`.
6. Yêu cầu bàn giao:
   - Ghi báo cáo khảo sát kỹ thuật vào `backend_survey_report.md` tại thư mục làm việc của bạn.
   - Tạo `handoff.md` tóm tắt toàn bộ phát hiện, sơ đồ kiến trúc lớp và hợp đồng giao tiếp cho orchestrator.
   - Dùng send_message gửi thông báo sau khi hoàn thành.
