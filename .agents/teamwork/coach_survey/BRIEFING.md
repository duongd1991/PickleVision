# BRIEFING — 2026-11-05T10:05:00Z

## Mission
Khảo sát, phân tích chuyên sâu và đặc tả toàn bộ quy tắc, thể thức và luật thi đấu chuẩn USA Pickleball phục vụ kiến trúc hệ thống và lập trình logic cho ứng dụng PickleVision Native iOS.

## 🔒 My Identity
- Archetype: Specification Miner / Athletic Coach
- Roles: Domain Expert (USA Pickleball Official Rules & Court Geometry Specification)
- Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\coach_survey\
- Original parent: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Milestone: M1 - Athletic Coach Survey & Official USA Pickleball Rules Specification

## 🔒 Key Constraints
- Khảo sát và đặc tả chính xác 100% luật thi đấu chuẩn USA Pickleball (Official Rulebook).
- Không trực tiếp can thiệp code ứng dụng (vai trò Specification Miner & Athletic Coach).
- Đặc tả chi tiết hình học sân (kích thước, tọa độ 2D/3D), quy tắc giao bóng (Serve) phân biệt với quy tắc bóng sống (Live Rally), quy tắc ô bếp (NVZ), Two-Bounce Rule, Kitchen Volley Fault và Rally State Machine.
- Viết tài liệu chi tiết vào `coach_rules_report.md` và tóm tắt bàn giao vào `handoff.md` theo 5-component protocol.
- Phản hồi và tài liệu bằng tiếng Việt theo quy định.

## Current Parent
- Conversation ID: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Updated: 2026-11-05T10:01:23Z

## Task Summary
- **What to build**: Tài liệu đặc tả kỹ thuật luật Pickleball chuẩn USA Pickleball (`coach_rules_report.md`) và báo cáo bàn giao (`handoff.md`).
- **Success criteria**: Đầy đủ 5 mục trọng tâm theo yêu cầu của orchestrator, chi tiết các bảng Feature Discovery, Edge Cases, thông số toán học chuẩn.
- **Interface contracts**: `coach_rules_report.md`
- **Code layout**: `.agents/teamwork/coach_survey/`

## Key Decisions Made
- Hệ tọa độ chuẩn: Cung cấp 2 hệ tọa độ chuẩn (Court Center Origin và Baseline Corner Origin) với đơn vị đo cả Mét (m) và Feet/Inches để Computer Vision và Game Engine dễ dàng ánh xạ homography matrix.
- Xử lý vạch biên và vạch bếp: Làm rõ sự khác biệt bản chất - vạch bếp là OUT/FAULT khi giao bóng nhưng là IN khi đánh bóng thường (khi bóng nảy); vạch biên/đáy luôn là IN nếu chạm bất kỳ phần nào của vạch.
- Quy tắc Let serve: Bỏ luật Let serve theo bản cập nhật chính thức của USA Pickleball (bóng chạm mép lưới rơi vào ô hợp lệ là bóng sống tiếp tục).
- Phân tích đà vô-lê trong bếp (NVZ Momentum Fault) và Two-Bounce Rule chi tiết với mô hình toán học và mã giả Swift cho Backend.

## Artifact Index
- DISPATCH.md — Chỉ thị nhiệm vụ từ orchestrator
- BRIEFING.md — Bộ nhớ trạng thái của Athletic Coach
- progress.md — Nhật ký tiến độ và heartbeat
- coach_rules_report.md — Bản đặc tả chuyên sâu luật và thể thức thi đấu
- handoff.md — Báo cáo bàn giao 5 thành phần cho orchestrator
