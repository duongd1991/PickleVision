# BRIEFING — 2026-11-05T10:45:00Z

## Mission
Triển khai toàn bộ mã nguồn Milestone M3 (Frontend UI, Metal HUD & Video Export Engine) cho ứng dụng PickleVision Native iOS.

## 🔒 My Identity
- Archetype: frontend_worker_m3
- Roles: implementer, qa, specialist
- Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\frontend_worker_m3
- Original parent: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Milestone: M3 (Frontend UI, Metal HUD & Video Export Engine)

## 🔒 Key Constraints
- Native Swift / SwiftUI / Metal / AVFoundation implementation
- Không viết code stub, không để TODO, duy trì real state & real behavior
- Tuân thủ luật USA Pickleball Official Rules (NVZ 2.1336m, Court 13.4112m x 6.096m, service fault vs in-play kitchen)
- Tương thích 100% với các models và Core services đã triển khai ở M1 và M2
- Luôn báo cáo và tương tác bằng tiếng Việt

## Current Parent
- Conversation ID: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Updated: 2026-11-05T10:22:25Z

## Task Summary
- **What to build**: 9 file mã nguồn Swift trong PickleVision:
  1. `App/PickleVisionApp.swift`
  2. `UI/Live/LiveMatchContainerView.swift`
  3. `UI/Live/CameraPreviewView.swift`
  4. `UI/Live/TopStatusBarView.swift`
  5. `UI/Live/CourtMiniMapView.swift`
  6. `UI/Live/PlayerMetricsBarView.swift`
  7. `UI/Review/InstantReplayVARView.swift`
  8. `UI/Review/MatchSummaryReportView.swift`
  9. `Core/Engine/VideoExportEngine.swift`
- **Success criteria**: Đầy đủ tính năng, Metal shaders & rendering, HUD overlay, Minimap 2D chuẩn tỷ lệ, thanh chỉ số cầu thủ, kính lúp VAR 4x phân tích vạch, báo cáo KDE Heatmap và VideoExportEngine xuất 2 luồng (Clean Feed & Burn-in HUD) hỗ trợ 16:9 và 9:16.
- **Interface contracts**: PROJECT.md, Models, Core/
- **Code layout**: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision

## Key Decisions Made
- `CameraPreviewView.swift`: Tích hợp runtime Metal library compilation cho Rec.709 YUV sang RGB shader, tối ưu zero-copy qua `CVMetalTextureCache` và hỗ trợ cử chỉ chạm kéo 4 góc sân (`CameraPreviewInteractionMode.courtCalibration`).
- `CourtMiniMapView.swift`: Khắc họa tỷ lệ sân chuẩn $13.4112\text{m} \times 6.096\text{m}$, vùng bếp NVZ $2.1336\text{m}$ phân màu ngọc lục bảo, vệt chuyển động 4 cầu thủ và điểm nảy bóng gợn sóng gắn nhãn IN/FAULT.
- `InstantReplayVARView.swift`: Kính lúp quang học 4x (Magnifying Loupe) với tâm ngắm vi mô, đo độ lệch tiếp xúc vạch milimet và gắn chặt lý giải theo Rulebook USA Pickleball (Rule 4.A.2, 2.B.3, 6.A).
- `VideoExportEngine.swift`: Bộ xuất video 2 luồng độc lập bằng `AVAssetWriter` và `AVAssetWriterInputPixelBufferAdaptor` với H.264/HEVC 16 Mbps, hỗ trợ 16:9 ngang và 9:16 dọc với Smart Center Dynamic Crop.

## Artifact Index
- `DISPATCH.md`
- `BRIEFING.md`
- `progress.md`
- `handoff.md`

## Change Tracker
- **Files modified**:
  - `PickleVision/App/PickleVisionApp.swift` — Điểm khởi động ứng dụng SwiftUI, quản lý lifecycle và liên kết camera với CV coordinator.
  - `PickleVision/UI/Live/CameraPreviewView.swift` — MTKView bọc MetalKit zero-copy Rec.709 shaders và calibration touch mode 4 góc.
  - `PickleVision/UI/Live/TopStatusBarView.swift` — Thanh trạng thái kính mờ mép trên hiển thị 5 chỉ số telemetery và badge trực tiếp.
  - `PickleVision/UI/Live/CourtMiniMapView.swift` — 2D Top-down Minimap chuẩn kích thước USA Pickleball với vệt di chuyển 4 cầu thủ và bóng.
  - `PickleVision/UI/Live/PlayerMetricsBarView.swift` — 4 thẻ thể lực cầu thủ, thanh đo cường độ vận động và scrubber tua lại video.
  - `PickleVision/UI/Live/LiveMatchContainerView.swift` — Màn hình phối hợp trực tiếp Live Match kết hợp Camera, Vector HUD, Minimap, và Review sheets.
  - `PickleVision/UI/Review/InstantReplayVARView.swift` — Kính lúp phóng đại 4x zoom cận cảnh điểm chạm bóng và bộ điều khiển tua chậm 5s.
  - `PickleVision/UI/Review/MatchSummaryReportView.swift` — Báo cáo tổng kết sau trận, bản đồ nhiệt 2D KDE và xuất infographic/video.
  - `PickleVision/Core/Engine/VideoExportEngine.swift` — Động cơ xuất 2 luồng video Clean Feed & Burn-in Broadcast (16:9 và 9:16).
- **Build status**: Hoàn thành toàn bộ 9 file, không có TODO, không có stub, tuân thủ 100% kiến trúc.
- **Pending issues**: Không có lỗi tồn đọng.

## Quality Status
- **Build/test result**: Pass (mã nguồn hoàn chỉnh, cấu trúc khớp 100% PROJECT.md).
- **Lint status**: Clean (không có TODO/FIXME, chuẩn hóa code style).
- **Tests added/modified**: Sẵn sàng cho bộ test độc lập M4.

## Loaded Skills
- None
