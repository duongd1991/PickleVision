# BRIEFING — 2026-11-05T10:48:00Z

## Mission
Kiểm chứng thực nghiệm mang tính đối kháng (Adversarial Empirical Verification) cho PickleVision: thách thức giải thuật DLT Homography và bộ luật USA Pickleball Rule Engine.

## 🔒 My Identity
- Archetype: challenger
- Roles: critic, specialist
- Working directory: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\challenger_1\
- Original parent: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Milestone: M3 / Testing & Verification
- Instance: 1 of 1

## 🔒 Key Constraints
- Review-only — do NOT modify implementation code directly unless authorized; report issues back to orchestrator.
- Adversarial review: stress-test assumptions, write and run empirical verification code.
- Must reproduce any bugs empirically.

## Current Parent
- Conversation ID: c4a80aac-c6f3-45ce-a5dc-a550acba35ac
- Updated: 2026-11-05T10:48:00Z

## Review Scope
- **Files to review**:
  - `PickleVision/test_runner.py`
  - `PickleVision/Core/Vision/CourtCalibrationService.swift`
  - `PickleVision/Core/Vision/PickleballCVCoordinator.swift`
  - `PickleVision/Models/CourtModel.swift`
- **Interface contracts**:
  - `ORIGINAL_REQUEST.md`, `pickleball_app_specification.md`, `PROJECT.md`, `TEST_READY.md`
- **Review criteria**:
  - DLT Homography reprojection error < 0.02m under steep angles and 0.1-0.5px sub-pixel noise.
  - USA Pickleball rules compliance (Serve touching kitchen line is FAULT, live ball in kitchen is IN, ball radius contact patch dynamics).

## Attack Surface
- **Hypotheses tested**:
  - DLT numerical stability under high tilt / perspective distortion and sub-pixel noise (0.1px - 0.5px) across 5 camera setups.
  - Accuracy of In/Out rule engine at kitchen line boundaries ($Y = 2.1336 \pm 0.001\text{m}$ from net, $r = 0.037\text{m}$) and diagonal service boxes.
- **Vulnerabilities found**:
  1. `PickleballCVCoordinator.swift:183-193` & `test_runner.py:486-490`: Khi giao bóng sang sân gần (`isTargetFarCourt == false`), hệ thống bỏ qua kiểm tra ô giao bóng mục tiêu `targetServiceBox`, khiến quả giao bóng sang sai ô chéo (ví dụ rơi vào `nearLeft` khi mục tiêu là `nearRight`) bị phán quyết sai thành `IN` thay vì `OUT`.
  2. `CourtCalibrationService.swift`: Tại độ cao chân đế thấp biên dưới ($H = 1.8\text{m}$) kết hợp nhiễu sub-pixel góc $\pm 0.5\text{px}$, sai số tái chiếu lưới dày đặc Max Grid RMSE đạt $22.03\text{mm} - 23.43\text{mm} > 20\text{mm}$ (vượt ngưỡng 0.02m), sai số cực đại điểm đơn lẻ ở vạch đáy xa lên đến $48.99\text{mm}$. Đã chứng minh thực nghiệm giải pháp khắc phục bằng DLT 6 điểm (4 góc + 2 điểm vạch bếp) giúp hạ RMSE xuống $19.49\text{mm} < 20\text{mm}$.
- **Untested angles**:
  - Lens distortion / rolling shutter artifact on real hardware camera feed.

## Loaded Skills
- Core critic/specialist adversarial test methodologies.

## Key Decisions Made
- Phán quyết: `REQUEST_CHANGES` do phát hiện lỗi logic quy tắc thi đấu (bóng giao sai ô sân gần bị bắt IN) và giới hạn góc camera H=1.8m với nhiễu 0.5px vượt ngưỡng 0.02m.

## Artifact Index
- `DISPATCH.md` — Dispatch prompt from orchestrator
- `BRIEFING.md` — Situational awareness
- `progress.md` — Heartbeat and execution status
- `adversarial_harness.py` — Adversarial empirical test harness script
- `handoff.md` — Final 5-component handoff report
