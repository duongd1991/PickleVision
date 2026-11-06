# BÁO CÁO BÀN GIAO THỂ THỨC & QUY TẮC THI ĐẤU (HANDOFF REPORT)
**Người lập**: Athletic Coach & Specification Miner  
**Đơn vị nhận**: Leader / Orchestrator (`c4a80aac-c6f3-45ce-a5dc-a550acba35ac`)  
**Dự án**: PickleVision Native iOS  
**Thư mục làm việc**: `c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\coach_survey\`  
**Tài liệu bàn giao chính**: `coach_rules_report.md`  

---

## 1. OBSERVATION (QUAN SÁT THỰC TẾ)
Qua rà soát và đối chiếu giữa `ORIGINAL_REQUEST.md` (dòng 18-20, 41, 59-60), `pickleball_app_specification.md` (dòng 17-23, 57-63, 71-76) và tài liệu quy chuẩn **USA Pickleball Official Rulebook (2024/2025/2026 Edition)**:

1. **Về kích thước sân**:
   - Chiều dài: $13.4112\text{ m}$ ($44\text{ ft}$), chiều rộng: $6.096\text{ m}$ ($20\text{ ft}$).
   - Vạch bếp Non-Volley Zone (NVZ): Cách lưới $2.1336\text{ m}$ ($7\text{ ft}$) mỗi bên (tổng chiều dài 2 bên bếp là $4.2672\text{ m}$).
   - Chiều cao lưới: $0.9144\text{ m}$ ($36\text{ in}$) ở 2 cột biên, $0.8636\text{ m}$ ($34\text{ in}$) ở tâm lưới.
   - Bề rộng tất cả các vạch sơn: $0.0508\text{ m}$ ($2\text{ in}$), nằm TRỌN VẸN BÊN TRONG kích thước sân thi đấu.

2. **Về quy tắc giao bóng (Serve) và vạch bếp**:
   - Trích dẫn nguyên văn luật USAP 4.A.2: *"The serve must clear the net and the NVZ, including the NVZ lines."*
   - Khẳng định quan sát: Khi giao bóng, vạch bếp (NVZ line) và toàn bộ khu vực bếp được tính là khu vực cấm. Nếu bóng giao chạm vạch bếp (dù chỉ 1 milimet tiếp xúc) $\rightarrow$ **FAULT (OUT ngay lập tức)**.
   - Trái lại, vạch biên (Sideline), vạch đáy (Baseline) và vạch giữa (Centerline) lại thuộc về ô giao bóng hợp lệ $\rightarrow$ Chạm các vạch này là **IN**.
   - Luật phát lại khi chạm lưới (Service Let): Kể từ năm 2021, USA Pickleball đã bỏ quy tắc Let. Nếu bóng chạm mép lưới rồi rơi vào ô hợp lệ $\rightarrow$ **BÓNG SỐNG (IN / LIVE)**, không phát lại.

3. **Về pha bóng sống (Live Rally)**:
   - Trong pha bóng sống, bóng rơi vào khu vực bếp hoặc chạm vạch bếp là **HOÀN TOÀN HỢP LỆ (IN)**.
   - Quy tắc 2 lần nảy (Two-Bounce Rule / USAP 4.A): Đội nhận giao bóng phải để bóng nảy 1 lần; đội giao bóng phải để cú trả bóng nảy 1 lần (cú thứ 3). Vô-lê ở cú 2 hoặc cú 3 là **FAULT**.
   - Lỗi vô-lê trong bếp (USAP Rule 9): Vô-lê khi chân chạm bếp hoặc đà di chuyển (momentum) đưa người/vợt/vật dụng chạm vào bếp $\rightarrow$ **FAULT**.

4. **Về máy trạng thái (Rally State Machine)**:
   - Gồm 4 trạng thái cốt lõi: `WAITING_FOR_SERVE` $\rightarrow$ `SERVE_IN_FLIGHT` $\rightarrow$ `IN_PLAY` $\rightarrow$ `RALLY_END`.
   - Cơ chế tính điểm đánh đôi: 3 con số (`Điểm giao` - `Điểm nhận` - `Thứ tự Server`). Khởi đầu trận đấu gọi điểm `0 - 0 - 2`.

---

## 2. LOGIC CHAIN (CHUỖI LẬP LUẬN VÀ SUY DIỄN)

1. **Từ hình học sân đến thuật toán DLT Homography ($H$)**:
   - Vì kích thước sân được chuẩn hóa tuyệt đối ($13.4112\text{m} \times 6.096\text{m}$), 4 góc sân thực tế thiết lập được tọa độ chuẩn: $(0, 0)$, $(6.096, 0)$, $(6.096, 13.4112)$, $(0, 13.4112)$.
   - Giải thuật DLT của `CourtCalibrationService.swift` sử dụng 4 điểm tương ứng trên mặt phẳng camera 2D để giải hệ phương trình tuyến tính qua LAPACK `dgesv`/`sgesv`, tìm ma trận $H_{3 \times 3}$ duy nhất thỏa mãn ánh xạ phối cảnh.

2. **Từ sự khác biệt giữa Giao bóng và Rally đến kiến trúc Phán quyết In/Out**:
   - Không thể dùng chung một hàm kiểm tra tọa độ cho cả trận đấu. Hàm phán quyết phải nhận tham số ngữ cảnh trạng thái (`RallyState` hoặc `isServe: Bool`).
   - Nếu `isServe == true`: Biên dưới của ô giao bóng hợp lệ là $(Y > Y_{\text{NVZ}} + \text{ballRadius})$. Vạch bếp là biên cấm.
   - Nếu `isServe == false`: Toàn bộ sân bên trong vạch biên/đáy (kể cả khu vực bếp) là hợp lệ ($0 \le X \le 6.096$ và $0 \le Y \le 13.4112$).

3. **Từ Two-Bounce Rule đến bộ đếm sự kiện chạm bóng (`shotCount`)**:
   - Bộ điều phối `PickleballCVCoordinator` cần theo dõi chuỗi sự kiện:
     - Khi `shotIndex == 2` (Return of serve) hoặc `shotIndex == 3` (Third shot), nếu phát hiện `ballBounceCount == 0` tại thời điểm chạm bóng của cầu thủ $\rightarrow$ Ngắt pha ngay lập tức và gán cờ `FAULT_TWO_BOUNCE`.

4. **Từ Kitchen Volley Fault đến bộ theo dõi cổ chân (Ankle Pose Tracking)**:
   - Khi phát hiện một cú vô-lê, không chỉ kiểm tra vị trí tiếp xúc bóng trên không mà phải tiếp tục theo dõi tọa độ cổ chân $(X_t, Y_t)$ trong khoảng thời gian cửa sổ trớn $\approx 1.0\text{s}$ sau cú đánh. Nếu cổ chân chạm hoặc vượt qua vạch bếp $\rightarrow$ Báo lỗi `FAULT_KITCHEN_VOLLEY`.

---

## 3. CAVEATS (LƯU Ý VÀ GIẢ ĐỊNH)

1. **Bán kính vật lý của quả bóng**:
   - Quả bóng pickleball tiêu chuẩn có đường kính từ $7.29\text{cm} \rightarrow 7.5\text{cm}$ ($r \approx 0.037\text{m}$). Khi bóng nảy, điểm tiếp xúc bị nén phẳng khoảng $1\text{cm} - 2\text{cm}$. Hệ thống CV cần tính toán vùng tiếp xúc bóng thay vì coi bóng là một điểm chất điểm $0\text{D}$.
2. **Quy tắc trần nhà và chướng ngại vật ngoài trời**:
   - Trong nhà thi đấu hoặc sân có mái che, bóng chạm trần nhà hoặc vật cản ngoài biên được tính là bóng chết (Dead ball/Out).
3. **Quy tắc Let Serve**:
   - Một số giải đấu giao hữu phong trào cũ có thể vẫn giữ luật Let Serve, nhưng ứng dụng tuân thủ nghiêm ngặt **chuẩn chuyên nghiệp USA Pickleball (No Let)**.

---

## 4. CONCLUSION (KẾT LUẬN & ĐỀ XUẤT HÀNH ĐỘNG)

Báo cáo đặc tả thể thức `coach_rules_report.md` đã hoàn tất 100% các yêu cầu:
1. Đã cung cấp chi tiết bảng tọa độ 2D/3D của 12 điểm chốt trên sân theo 2 hệ quy chiếu (Baseline Corner Origin và Court Center Origin) để đội ngũ Backend đưa vào `CourtModel.swift` và `CourtCalibrationService.swift`.
2. Đã phân định rõ ranh giới toán học cho trường hợp vạch bếp FAULT khi giao bóng và IN khi bóng sống để đưa vào `PickleballCVCoordinator.swift`.
3. Đã đặc tả logic Two-Bounce Rule và Kitchen Volley Fault để tích hợp với bộ lọc cổ chân `PlayerTrackerService.swift`.
4. Đã xây dựng hoàn chỉnh sơ đồ máy trạng thái (Rally State Machine) 4 trạng thái cho `RallyEngine.swift`.
5. Đã đề xuất 5 kịch bản XCTest chuẩn cho Tester đưa vào kiểm thử độc lập.

---

## 5. VERIFICATION METHOD (PHƯƠNG PHÁP KIỂM TRA ĐỘC LẬP)

Để kiểm chứng tính chính xác của các đặc tả này:
1. **Kiểm tra tài liệu đặc tả**:
   - Mở file `coach_rules_report.md` tại thư mục `.agents/teamwork/coach_survey/coach_rules_report.md`.
   - Đối chiếu Mục 2 với Official Rulebook USA Pickleball (Section 2 - Court Specs).
   - Đối chiếu Mục 3 với USAP Rule 4.A (Service Rules).
   - Đối chiếu Mục 4 với USAP Rule 9 (Non-Volley Zone Rules) và Rule 4.A (Two-Bounce Rule).
2. **Kiểm tra tính nhất quán toán học**:
   - Kiểm tra tổng khoảng cách: $4.572\text{m} \text{ (Service Court)} + 2.1336\text{m} \text{ (NVZ)} = 6.7056\text{m}$ (Nửa sân).
   - Cả sân: $6.7056\text{m} \times 2 = 13.4112\text{m}$ ($44\text{ ft}$). Khớp hoàn hảo đến từng milimet.
