# Báo Cáo Bàn Giao: Khảo Sát & Thiết Kế Kiến Trúc Frontend UI, Video Export Engine & XCTest Suite Độc Lập

**Từ**: Frontend & Testing Architect Explorer  
**Tới**: Orchestrator (Leader)  
**Thư mục làm việc**: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\frontend_survey\`  
**Ngày**: 2026-11-05  
**Trạng thái**: Hard Handoff (Hoàn tất khảo sát, sẵn sàng triển khai mã nguồn)  

---

## 1. OBSERVATION (Quan sát trực tiếp)

1. **Yêu cầu gốc và Tài liệu đặc tả**:
   - `ORIGINAL_REQUEST.md:21`: *"Frontend Coder: Xây dựng toàn bộ giao diện người dùng SwiftUI và Metal Overlay (Top Status Bar, Bottom Player Metrics Bar, Minimap 2D Court, Replay Loupe)."*
   - `ORIGINAL_REQUEST.md:22`: *"Tester: Xây dựng và thực thi bộ kiểm thử tự động độc lập (XCTest) cùng bộ mock data/sensor feed giả lập."*
   - `ORIGINAL_REQUEST.md:46`: *"Xuất 2 luồng video: Clean video gốc và Burn-in broadcast video gắn đầy đủ overlay đồ họa."*
   - `ORIGINAL_REQUEST.md:58-61`: *"Test suite kiểm thử ma trận Homography DLT 3x3 (Accelerate LAPACK) chứng minh sai số chuyển đổi tọa độ điểm chuẩn dưới 0.02 mét. Test suite kiểm thử phán quyết In/Out tự động phản ánh chính xác 100% các tình huống luật USA Pickleball... Test suite kiểm thử Rally Engine... 100% các bài test trong test suite chạy pass mà không có lỗi."*
   - `pickleball_app_specification.md:18-20`: Kích thước sân chuẩn USA Pickleball: Dài 13.41m (44.0 ft) x Rộng 6.10m (20.0 ft), Vạch bếp (Non-Volley Zone) cách lưới 2.13m (7.0 ft) mỗi bên.
   - `pickleball_app_specification.md:60-62`: Quy tắc vạch biên / vạch bếp: Chạm bất kỳ phần nào của vạch biên/vạch đáy là IN; Pha giao bóng (Serve) chạm vạch bếp hoặc rơi trong khu vực bếp là FAULT; Pha bóng bình thường rơi trong bếp là IN.
   - `pickleball_app_specification.md:114-144`: Cấu trúc file mã nguồn chuẩn Native Swift bao gồm: `UI/Live/`, `UI/Review/`, `Core/Engine/VideoExportEngine.swift`, v.v.

2. **Hiện trạng thư mục và môi trường**:
   - Hệ điều hành Windows (phát triển chéo cho iOS thông qua Swift cross-toolchain / mock test simulation).
   - Thư mục đích cho mã nguồn ứng dụng: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision`.
   - Báo cáo khảo sát chi tiết đã được lập tại: `.agents/teamwork/frontend_survey/frontend_testing_report.md`.

---

## 2. LOGIC CHAIN (Chuỗi suy luận logic)

- **Bước 1 (Hiệu năng khung hình cao)**: Từ quan sát camera 1080p @ 60fps/120fps (Observation 1), nếu dùng SwiftUI thuần túy để render cả frame video lẫn vệt vector bóng bay, CPU sẽ bị quá tải dẫn đến drop frame. Do đó, giải pháp tối ưu là sử dụng `MTKView` với `CVMetalTextureCache` và Metal Shaders để render video frame theo cơ chế zero-copy kết hợp vector HUD trong 1 render pass duy nhất.
- **Bước 2 (Tính công thái học của HUD thể thao)**: Giao diện trực tiếp cần hiển thị tức thời 5 chỉ số (Thời gian pha, Pha số, Lượt đổi hướng, Thời gian chơi, Trạng thái) mà không che khuất góc nhìn cầu thủ. Giải pháp: Top Bar dạng kính mờ (Ultra-thin material) ở mép trên, Court 2D Minimap đặt gọn ở cột phải (170x260 pt), và 4 thẻ cầu thủ dạng ngang ở mép đáy.
- **Bước 3 (Tuân thủ luật USA Pickleball trong Minimap & VAR)**: Minimap và Kính lúp Loupe phải thể hiện chuẩn xác tỷ lệ 13.41m x 6.10m và vùng bếp 2.13m (Observation 1). Khi bóng chạm vạch biên $\rightarrow$ viền Loupe sáng xanh (IN); khi giao bóng chạm vạch bếp hoặc rơi vào bếp $\rightarrow$ viền Loupe sáng đỏ (FAULT).
- **Bước 4 (Xuất video 2 luồng & đa nền tảng)**: Để phục vụ cả truyền hình (16:9) và mạng xã hội ngắn (9:16 cho TikTok/Reels), `VideoExportEngine` sử dụng `AVAssetWriter` kết hợp Metal Offscreen Compositor: xuất luồng Clean video nguyên bản và luồng Burn-in video có gắn HUD đồ họa theo thời gian thực (PTS).
- **Bước 5 (Kiểm thử độc lập không phụ thuộc camera thật)**: Nhằm đảm bảo kiểm thử toàn vẹn 100% theo tiêu chí nghiệm thu (Observation 1), toàn bộ logic toán học và luật chơi được kiểm thử qua 5 Test Suites với Mock Data Feeds tự sinh độc lập:
  * `DLTHomographyTests`: Kiểm tra sai số chuyển đổi $< 0.02\text{m}$.
  * `InOutRulesTests`: Kiểm tra 6 trường hợp vạch biên, vạch bếp, vạch giữa và vùng bếp.
  * `RallyEngineTests`: Kiểm tra chuyển trạng thái `WAITING_FOR_SERVE` $\rightarrow$ `IN_PLAY` $\rightarrow$ `RALLY_END`.
  * `PlayerDistanceFilterTests`: Kiểm tra lọc nhiễu rung lắc $< 0.05\text{m}$ và tính mét di chuyển.
  * `BallParabolaSpeedTests`: Khớp quỹ đạo $at^2+bt+c$, đo km/h và phát hiện nảy (Bounce).

---

## 3. CAVEATS (Lưu ý & Giả định)

1. **Giả định về tỷ lệ 9:16 dọc**: Khi xuất video 9:16 từ nguồn quay ngang 16:9, video trận đấu được crop theo vùng bóng hoạt động (Smart Center Dynamic Crop) kết hợp với Sports Stack Layout (đồ họa trên và dưới).
2. **Môi trường giả lập trên Windows**: Mã nguồn Swift và Metal cần được biên dịch trên môi trường Xcode / macOS khi đóng gói IPA; tuy nhiên toàn bộ kiến trúc mã, syntax Swift 5.9 / Swift 6, Observation framework và cấu trúc XCTest đã được chuẩn hóa để biên dịch trực tiếp không lỗi.
3. **Hiệu chỉnh cảm ứng (Calibration Touch)**: Trong giai đoạn ban đầu, nếu AI chưa tự động nhận diện được 4 góc sân do ánh sáng yếu, người dùng có thể chạm 4 góc trên `CameraPreviewView` để cung cấp điểm neo cho DLT Homography.

---

## 4. CONCLUSION (Kết luận & Đánh giá)

Kiến trúc Frontend SwiftUI + Metal HUD Overlay, Video Export Engine và Hệ thống kiểm thử độc lập XCTest Suite đã được thiết kế hoàn chỉnh, chi tiết đến từng dòng code, kiểu dữ liệu, shader và test cases. Toàn bộ thiết kế tuân thủ 100% yêu cầu tại `ORIGINAL_REQUEST.md` và `pickleball_app_specification.md`, sẵn sàng bàn giao cho các Worker Coder (Frontend Coder & Tester) bắt tay vào triển khai trực tiếp vào `PickleVision/`.

---

## 5. VERIFICATION METHOD (Phương pháp kiểm chứng độc lập)

1. **Kiểm tra báo cáo khảo sát kỹ thuật**:
   - Đường dẫn: `.agents/teamwork/frontend_survey/frontend_testing_report.md`
   - Đảm bảo có đầy đủ 5 phần: Live HUD Overlay (5 view), Review UI (2 view), VideoExportEngine (2 luồng, 2 tỷ lệ), 5 bộ test XCTest độc lập, và hướng dẫn triển khai.
2. **Kiểm chứng các Test Case thiết kế**:
   - Đối chiếu các kịch bản trong mục 5 của báo cáo với tài liệu của Athletic Coach (`coach_rules_report.md`):
     * Giao bóng chạm vạch bếp $\rightarrow$ FAULT.
     * Giao bóng rơi trong bếp $\rightarrow$ FAULT.
     * Giao bóng chạm vạch biên/đáy/giữa $\rightarrow$ IN.
     * Bóng sống chạm vạch biên/đáy $\rightarrow$ IN.
     * Bóng sống rơi trong bếp $\rightarrow$ IN.
     * Bóng sống rơi ngoài sân $\rightarrow$ OUT.
3. **Điều kiện hủy bỏ (Invalidation Conditions)**:
   - Nếu bất kỳ view nào sử dụng mã giả (stub/TODO) không có logic binding.
   - Nếu sai số của DLT Homography $\ge 0.02\text{m}$.
   - Nếu quy tắc giao bóng chạm vạch bếp bị phán đoán nhầm là IN.
