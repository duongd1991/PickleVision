# Handoff Report — Challenger 1 (Adversarial Empirical Verification)

## 1. Observation

### Quan sát 1.1: Chạy bộ kiểm thử cơ sở `PickleVision\test_runner.py`
- Lệnh thực thi: `python PickleVision\test_runner.py`
- Kết quả: Mã thoát 0.
- Output nguyên văn:
  ```
  Total Assertions Checked : 162
  Passed Assertions        : 162
  Failed Assertions        : 0
  Execution Time           : 0.001 seconds
  Pass Rate                : 100.00%
  *** ALL 6 TEST SUITES PASSED (100% SUCCESS) ***
  ```

### Quan sát 1.2: Thách thức đối kháng giải thuật DLT Homography qua 5 cấu hình camera & nhiễu Sub-pixel
- Script kiểm thử đối kháng do Challenger 1 xây dựng: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\challenger_1\adversarial_harness.py`
- Lệnh thực thi: `python .agents\teamwork\challenger_1\adversarial_harness.py`
- Đo đạc trên 100 điểm lưới phủ khắp toàn bộ sân thi đấu ($10 \times 10$ dense court grid, $X \in [0, 6.096\text{m}], Y \in [0, 13.4112\text{m}]$) qua 100 lần thử nghiệm Monte-Carlo ngẫu nhiên cho từng mức nhiễu $\pm 0.10\text{px}, \pm 0.20\text{px}, \pm 0.35\text{px}, \pm 0.50\text{px}$:
  1. **Standard Baseline Central** ($H = 2.2\text{m}, \text{Dist} = 3.0\text{m}, \text{Pitch} = 20^\circ$):
     - Nhiễu $\pm 0.10\text{px}$: Max Grid RMSE = $3.19\text{mm}$, Worst Point Err = $7.61\text{mm}$ (PASS)
     - Nhiễu $\pm 0.20\text{px}$: Max Grid RMSE = $6.38\text{mm}$, Worst Point Err = $15.17\text{mm}$ (PASS)
     - Nhiễu $\pm 0.35\text{px}$: Max Grid RMSE = $11.40\text{mm}$, Worst Point Err = $25.98\text{mm}$ (PASS)
     - Nhiễu $\pm 0.50\text{px}$: Max Grid RMSE = $14.57\text{mm}$, Worst Point Err = $37.47\text{mm}$ (PASS $< 0.02\text{m}$)
  2. **High Tripod Baseline** ($H = 2.5\text{m}, \text{Dist} = 3.5\text{m}, \text{Pitch} = 22^\circ$):
     - Nhiễu $\pm 0.50\text{px}$: Max Grid RMSE = $17.52\text{mm} < 20\text{mm}$ (PASS)
  3. **Steep Pitch Challenge** ($H = 2.5\text{m}, \text{Dist} = 2.6\text{m}, \text{Pitch} = 25^\circ$):
     - Nhiễu $\pm 0.50\text{px}$: Max Grid RMSE = $12.45\text{mm} < 20\text{mm}$ (PASS)
  4. **Corner Baseline Angled** ($H = 2.2\text{m}, X = -1.0\text{m}, Y = -3.0\text{m}, \text{Pitch} = 20^\circ, \text{Yaw} = 12^\circ$):
     - Nhiễu $\pm 0.50\text{px}$: Max Grid RMSE = $19.32\text{mm} < 20\text{mm}$ (PASS)
  5. **Low Tripod Baseline** ($H = 1.8\text{m}, \text{Dist} = 3.0\text{m}, \text{Pitch} = 17^\circ$ - biên dưới của đặc tả $1.8\text{m} - 2.5\text{m}$):
     - Nhiễu $\pm 0.10\text{px}$: Max Grid RMSE = $4.58\text{mm}$ (PASS)
     - Nhiễu $\pm 0.20\text{px}$: Max Grid RMSE = $8.79\text{mm}$ (PASS)
     - Nhiễu $\pm 0.35\text{px}$: Max Grid RMSE = $13.68\text{mm}$ (PASS)
     - **Nhiễu $\pm 0.50\text{px}$**: Max Grid RMSE = **$22.03\text{mm}$ ($0.02203\text{m} \ge 0.02\text{m}$)** (FAIL), Worst Single Point Error = **$48.99\text{mm}$** (tại góc vạch đáy xa).

### Quan sát 1.3: Thách thức quy tắc In/Out của luật USA Pickleball tại vạch bếp
- Quét siêu mịn sát vạch bếp sân xa ($Y = 8.8392\text{m}$) và bán kính bóng $r = 0.037\text{m}$:
  - $Y = 8.7892\text{m}$ (trong bếp): Serve = `FAULT_KITCHEN_SERVE`, Live = `IN` (PASS)
  - $Y = 8.8392\text{m}$ (trên vạch bếp): Serve = `FAULT_KITCHEN_SERVE`, Live = `IN` (PASS)
  - $Y = 8.8752\text{m}$ ($8.8392 + r - 1\text{mm}$, liếm vạch bếp $1\text{mm}$): Serve = `FAULT_KITCHEN_SERVE`, Live = `IN` (PASS)
  - $Y = 8.8762\text{m}$ ($8.8392 + r$, tiếp xúc tiếp tuyến): Serve = `FAULT_KITCHEN_SERVE`, Live = `IN` (PASS)
  - $Y = 8.8772\text{m}$ ($8.8392 + r + 1\text{mm}$, mép bóng cách vạch bếp $1\text{mm}$): Serve = `IN`, Live = `IN` (PASS)
- Thử nghiệm khoảng cách từ lưới ($2.1336\text{m} \pm 0.001\text{m}$):
  - $2.1326\text{m}$ ($-1\text{mm}$): Serve = `FAULT_KITCHEN_SERVE` (100% FAULT: True)
  - $2.1336\text{m}$ ($0\text{mm}$): Serve = `FAULT_KITCHEN_SERVE` (100% FAULT: True)
  - $2.1346\text{m}$ ($+1\text{mm}$): Serve = `FAULT_KITCHEN_SERVE` (100% FAULT: True)

### Quan sát 1.4: Phát hiện lỗi logic quy tắc thi đấu (Rule Engine Bug) khi giao bóng sang sân gần
- Tệp mã nguồn: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\Core\Vision\PickleballCVCoordinator.swift`, dòng 160–193:
  ```swift
  if isServe {
      // Giả định cú giao bóng bay từ Near Side sang Far Side (hoặc kiểm tra targetServiceBox)
      let isTargetFarCourt = y > CourtDimensions.netY
      
      if isTargetFarCourt {
          if y <= (CourtDimensions.farNVZY + r) {
              return .faultKitchenServe
          }
          if let target = targetServiceBox {
              let minX = target.bounds.minX - r
              let maxX = target.bounds.maxX + r
              let maxY = target.bounds.maxY + r
              if x >= minX && x <= maxX && y <= maxY {
                  return .inBound
              } else {
                  return .outOfBound
              }
          }
      } else {
          // Sân gần: Vạch bếp nằm ở Y = 4.5720m
          // Nếu bóng chạm vạch bếp (Y >= 4.5720 - r) hoặc rơi trong khu vực bếp -> FAULT NGAY!
          if y >= (CourtDimensions.nearNVZY - r) {
              return .faultKitchenServe
          }
      }
      
      // Nếu không vi phạm vạch bếp và trong sân -> IN
      return .inBound
  }
  ```
- Tệp mã nguồn: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\PickleVision\test_runner.py`, dòng 475–492:
  ```python
  if is_serve:
      if y > NET_Y:
          if y <= (FAR_NVZ_Y + r):
              return "FAULT_KITCHEN_SERVE"
          if target_box == "farRight":
              ...
      else:
          if y >= (NEAR_NVZ_Y - r):
              return "FAULT_KITCHEN_SERVE"
      return "IN"
  ```
- Kiểm chứng thực nghiệm (Lệnh: `python -c "..."`):
  - Tình huống: Đội bạn đứng ở sân xa giao bóng sang sân gần, nhắm vào ô chéo `nearRight` ($X \in [3.048, 6.096], Y \in [0, 4.572]$).
  - Quả giao bóng rơi vào ô `nearLeft` ($X = 1.5\text{m}, Y = 2.0\text{m}$) — hoàn toàn sai ô giao bóng chéo theo luật USA Pickleball Rule 4.A.2.
  - Kết quả trả về thực tế: **`IN`** (Kỳ vọng: **`OUT`**).

---

## 2. Logic Chain

1. **Từ Quan sát 1.4**:
   - Luật USA Pickleball Rule 4.A.2 quy định: Quả phát bóng bắt buộc phải bay chéo sân và rơi trong ô giao bóng hợp lệ đối diện.
   - Khi một đội phát bóng từ sân xa sang sân gần (xảy ra trong tất cả các lượt giao bóng của đội xa sau khi đổi quyền giao bóng Side-out): ô mục tiêu là `.nearRight` hoặc `.nearLeft`.
   - Trong `PickleballCVCoordinator.swift` dòng 183–193 và `test_runner.py` dòng 486–492, nhánh `else` (dành cho sân gần) chỉ kiểm tra `y >= (nearNVZY - r)` rồi bỏ qua toàn bộ việc kiểm tra `targetServiceBox.bounds`, tự động `return .inBound`.
   - Dẫn đến việc bóng giao rơi vào sai ô giao bóng ở sân gần bị tính điểm thành công (`IN`) thay vì bắt lỗi bóng ra ngoài (`OUT`). Đây là lỗi logic quy tắc thi đấu (Flaw in Rule Engine).

2. **Từ Quan sát 1.2**:
   - Ở độ cao camera $H = 1.8\text{m}$ (thuộc dải 1.8m – 2.5m trong mục 1 của tài liệu đặc tả), góc nhìn tới vạch đáy xa (cách camera $\sim 16.4\text{m}$) rất nông ($\approx 6.25^\circ$), gây hiện tượng nén phối cảnh cực mạnh (perspective foreshortening: $1\text{px} \approx 11\text{cm}$ trên sân).
   - Khi có nhiễu sub-pixel $\pm 0.5\text{px}$, sai số tái chiếu cực đại trên lưới toàn sân (Max Grid RMSE) đạt $22.03\text{mm} - 23.43\text{mm}$, vượt ngưỡng yêu cầu $< 0.02\text{m}$ ($20\text{mm}$).
   - Ngược lại, khi đặt máy ở $H \ge 2.2\text{m} - 2.5\text{m}$, Max Grid RMSE luôn duy trì ở mức $14.57\text{mm} - 17.52\text{mm} < 20\text{mm}$.
   - Hơn nữa, qua thử nghiệm thực nghiệm bổ sung, nếu nâng cấp DLT từ 4 điểm chốt góc lên 6 điểm (bổ sung 2 điểm vạch bếp như mô tả trong mục 2 của tài liệu đặc tả), Max Grid RMSE ở $H = 1.8\text{m}$ giảm xuống còn $19.49\text{mm} < 20\text{mm}$ và trung bình chỉ $9.02\text{mm}$. Tuy nhiên, hiện tại `CourtCalibrationService.swift:83` chỉ dùng `corners.prefix(4)`.

3. **Từ Quan sát 1.3**:
   - Đối với các pha giao bóng ở sân xa, giải thuật xử lý tiếp xúc bán kính bóng $r = 0.037\text{m}$ hoạt động chính xác 100%: mọi điểm rơi chạm hoặc đè lên vạch bếp (kể cả liếm vạch 1mm tại $Y = 8.8752\text{m}$ và $Y = 8.8762\text{m}$) đều bị bắt `FAULT_KITCHEN_SERVE` 100%. Khi cách vạch bếp 1mm ($Y = 8.8772\text{m}$), bóng được tính `IN`.
   - Bóng sống (live rally) rơi trong khu vực bếp hoặc chạm vạch bếp luôn được tính `IN` 100% đúng luật USAP Rule 2.B.3.

---

## 3. Caveats

- Thử nghiệm đối kháng được tiến hành bằng mô phỏng quang học Pinhole 1080p và phân rã kỳ dị SVD Jacobi/LAPACK trong môi trường toán học chính xác cao, chưa tính tới độ méo quang học ống kính vật lý thực tế (Barrel/Pincushion Distortion của camera iPhone góc rộng) vì phần cứng camera vật lý chưa được kết nối trực tiếp trên máy chủ Windows.
- Khẳng định 100% FAULT khi bóng giao liếm mép vạch bếp hoạt động hoàn hảo trên sân xa, nhưng tính toàn vẹn của pha giao bóng sân gần bị ảnh hưởng bởi lỗi bỏ sót kiểm tra ô giao bóng chéo.

---

## 4. Conclusion

**Phán quyết**: **`REQUEST_CHANGES`** (Yêu cầu chỉnh sửa trước khi nghiệm thu M4/M5).

**Các hạng mục cần đội ngũ khắc phục**:
1. **Sửa lỗi Rule Engine trong `PickleballCVCoordinator.swift` & `test_runner.py`**:
   - Bổ sung kiểm tra `targetServiceBox` cho trường hợp phát bóng sang sân gần (`isTargetFarCourt == false`), kiểm tra toạ độ $(X, Y)$ có nằm trong `target.bounds` mở rộng dung sai bán kính bóng $r$ của ô `nearLeft` / `nearRight` hay không. Nếu nằm ngoài ô mục tiêu thì phải trả về `.outOfBound` (`OUT`).
2. **Khuyến cáo hoặc nâng cấp thuật toán DLT Homography cho camera thấp**:
   - Hoặc cập nhật hướng dẫn kỹ thuật / điều kiện tiên quyết: Yêu cầu chân đế Tripod đặt máy ở độ cao tối thiểu $H \ge 2.0\text{m}$ (tối ưu $2.2\text{m} - 2.5\text{m}$) sau vạch đáy để bảo đảm sai số tái chiếu luôn nghiêm ngặt $< 0.02\text{m}$ dưới nhiễu sub-pixel $\pm 0.5\text{px}$.
   - Hoặc nâng cấp hàm `computeHomographyDLT` trong `CourtCalibrationService.swift` để hỗ trợ DLT đa điểm (Overdetermined DLT với 6 điểm: 4 góc sân + 2 điểm vạch bếp), giúp bảo đảm sai số $< 0.02\text{m}$ ngay cả ở độ cao thấp $H = 1.8\text{m}$.

---

## 5. Verification Method

Để tái hiện độc lập các phát hiện trên:
1. **Kiểm tra lỗi giao bóng sai ô sân gần**:
   ```powershell
   python -c "import sys; sys.path.insert(0, 'PickleVision'); from test_runner import PickleballCVCoordinator, CourtCalibrationService, RallyEngine; calib = CourtCalibrationService(); engine = RallyEngine(); coord = PickleballCVCoordinator(calib, engine); print(coord.evaluate_bounce_verdict((1.5, 2.0), is_serve=True, target_box='nearRight'))"
   ```
   - Kết quả xuất ra: `IN` (Sai lệch: Phải là `OUT`).
2. **Chạy bộ thử nghiệm đối kháng tổng thể**:
   ```powershell
   python .agents\teamwork\challenger_1\adversarial_harness.py
   ```
   - Quan sát kết quả tại cấu hình `Low Tripod Baseline (H=1.8m)` với nhiễu $\pm 0.50\text{px}$ cho Max Grid RMSE $= 22.03\text{mm} > 20\text{mm}$.
