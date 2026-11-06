# BÁO CÁO CỐ VẤN THỂ THỨC & QUY TẮC THI ĐẤU CHUẨN USA PICKLEBALL
**Dự án**: PickleVision Native iOS (Live Pickleball Computer Vision & Analytics)  
**Tác giả**: Athletic Coach & Specification Miner  
**Phiên bản quy chuẩn tham chiếu**: USA Pickleball Official Rulebook (2024/2025/2026 Edition)  
**Ngày lập**: 2026-11-05  

---

## MỤC LỤC
1. [Tổng Quan & Phạm Vi Cố Vấn](#1-tổng-quan--phạm-vi-cố-vấn)
2. [Kích Thước Hình Học & Hệ Tọa Độ Chuẩn 2D/3D Của Sân](#2-kích-thước-hình-học--hệ-tọa-độ-chuẩn-2d3d-của-sân)
3. [Quy Tắc Giao Bóng (Serve Rules) & Ngoại Lệ Vạch Bếp](#3-quy-tắc-giao-bóng-serve-rules--ngoại-lệ-vạch-bếp)
4. [Quy Tắc Trong Pha Bóng Sống (Live Rally Rules)](#4-quy-tắc-trong-pha-bóng-sống-live-rally-rules)
5. [Máy Trạng Thái Pha Bóng & Thể Thức Trận Đấu (Rally State Machine)](#5-máy-trạng-thái-pha-bóng--thể-thức-trận-đấu-rally-state-machine)
6. [Bảng Phát Hiện Tính Năng (Features Discovered)](#6-bảng-phát-hiện-tính-năng-features-discovered)
7. [Bảng Trường Hợp Biên & Tình Huống Phức Tạp (Edge Cases)](#7-bảng-trường-hợp-biên--tình-huống-phức-tạp-edge-cases)
8. [Đặc Tả Kỹ Thuật Dành Cho Backend, Frontend & Tester](#8-đặc-tả-kỹ-thuật-dành-cho-backend-frontend--tester)

---

## 1. TỔNG QUAN & PHẠM VI CỐ VẤN

Tài liệu này cung cấp toàn bộ đặc tả toán học, luật thi đấu chính thức và logic nghiệp vụ theo chuẩn của **USA Pickleball (USAP)** nhằm định hướng trực tiếp cho các đội ngũ phát triển ứng dụng **PickleVision Native iOS**:
- **Backend Coder**: Triển khai chính xác ma trận Homography DLT $3 \times 3$, thuật toán phán quyết bóng rơi Trong/Ngoài sân (In/Out Decision Engine), phát hiện lỗi khu vực bếp (Non-Volley Zone Fault), và máy trạng thái pha bóng (Rally State Machine).
- **Frontend Coder**: Dựng đồ họa Minimap 2D sân chính xác tỷ lệ, vẽ vạch sân, hiển thị quỹ đạo bóng và các cảnh báo lỗi trực quan trên HUD.
- **Tester**: Xây dựng bộ dữ liệu kiểm thử (Mock Test Suite & XCTest) bao phủ 100% các tình huống biên và kịch bản thi đấu.

---

## 2. KÍCH THƯỚC HÌNH HỌC & HỆ TỌA ĐỘ CHUẨN 2D/3D CỦA SÂN

Theo Mục 2 (Court and Equipment Specifications) trong USA Pickleball Official Rulebook:

### 2.1. Kích thước tiêu chuẩn
- **Chiều dài tổng thể (Court Length)**: $13.4112\text{ m}$ ($44\text{ ft}$).
- **Chiều rộng tổng thể (Court Width)**: $6.096\text{ m}$ ($20\text{ ft}$).
- **Khu vực bếp (Non-Volley Zone - NVZ)**: Trải dài $2.1336\text{ m}$ ($7\text{ ft}$) từ lưới về mỗi bên sân. Tổng chiều dài cả 2 bên bếp là $4.2672\text{ m}$ ($14\text{ ft}$).
- **Khu vực ô giao bóng (Service Court)**: Mỗi bên gồm 2 ô (Trái và Phải), mỗi ô có kích thước:
  - Chiều rộng: $3.048\text{ m}$ ($10\text{ ft}$).
  - Chiều dài: $4.572\text{ m}$ ($15\text{ ft}$) tính từ vạch bếp (NVZ line) đến vạch đáy (Baseline).
- **Độ rộng vạch kẻ sân (Line Width)**: $0.0508\text{ m}$ ($2\text{ inches}$).  
  *Nguyên tắc đo đạc*: Toàn bộ độ rộng vạch nằm **TRONG** phạm vi kích thước của sân thi đấu.
- **Kích thước lưới (Net Specs)**:
  - Chiều dài lưới: Tối thiểu $6.71\text{ m}$ ($22\text{ ft}$) (vươn ra ngoài mỗi vạch biên ít nhất $0.305\text{ m} / 1\text{ ft}$).
  - Chiều cao tại 2 cột biên (Sideline / Posts): $0.9144\text{ m}$ ($36\text{ inches}$).
  - Chiều cao tại tâm lưới (Center Net): $0.8636\text{ m}$ ($34\text{ inches}$) có đai giữ cố định (Center strap).

---

### 2.2. Hệ Tọa Độ Chuẩn Toán Học (Court Coordinate Models)

Để phục vụ bài toán biến đổi Homography DLT $3 \times 3$ trong Computer Vision và vẽ giao diện Minimap 2D, PickleVision áp dụng 2 hệ tọa độ chuẩn:

#### Hệ Tọa Độ 1: Gốc Tọa Độ Đặt Tại Góc Đáy Sân Phía Camera (Baseline Corner Origin)
Phù hợp nhất cho giải thuật Direct Linear Transformation (DLT) và hiển thị Minimap từ góc nhìn người dùng:
- Gốc $O(0, 0, 0)$: Góc đáy sân bên trái của Đội Nhà (Bottom-Left Baseline Corner).
- Trục $+X$: Hướng theo chiều ngang sân từ Trái sang Phải ($0.0\text{ m} \rightarrow 6.096\text{ m}$).
- Trục $+Y$: Hướng theo chiều dọc sân từ Đội Nhà sang Đội Khách ($0.0\text{ m} \rightarrow 13.4112\text{ m}$).
- Trục $+Z$: Hướng thẳng đứng lên trên mặt đất ($0.0\text{ m} \rightarrow$ độ cao bóng/lưới).

```
                      ĐỘI KHÁCH (FAR SIDE / TEAM B)
       (0, 13.4112) -------------------------------- (6.096, 13.4112)
                    |     Ô Phải      |     Ô Trái     |  Far Baseline
                    |   (Far Right)   |   (Far Left)   |
       (0, 8.8392)  |-----------------|----------------| (6.096, 8.8392)
                    |         BẾP XA (Far NVZ)         |  Far NVZ Line
       (0, 6.7056)  ==================================== (6.096, 6.7056)
                    | ~ ~ ~ ~ ~ ~ ~ LƯỚI ~ ~ ~ ~ ~ ~ ~ |  Center Net
       (0, 4.5720)  |-----------------|----------------| (6.096, 4.5720)
                    |         BẾP GẦN (Near NVZ)       |  Near NVZ Line
                    |     Ô Trái      |     Ô Phải     |
                    |   (Near Left)   |  (Near Right)  |
          O (0, 0)  ------------------------------------ (6.096, 0)
                      ĐỘI NHÀ (NEAR SIDE / TEAM A - CAMERA)
```

#### Tọa Độ 2D/3D Chi Tiết Của Các Điểm Chốt (Key Landmarks):

| Điểm Chốt (Keypoint) | Tọa Độ $X$ (m) | Tọa Độ $Y$ (m) | Tọa Độ $Z$ (m) | Tên Gọi Kỹ Thuật |
|:---|:---:|:---:|:---:|:---|
| **$P_1$ (Near BL Left)** | $0.0000$ | $0.0000$ | $0.0000$ | Góc đáy trái sân gần (Gốc tọa độ) |
| **$P_2$ (Near BL Center)** | $3.0480$ | $0.0000$ | $0.0000$ | Giao điểm vạch giữa và đáy gần |
| **$P_3$ (Near BL Right)** | $6.0960$ | $0.0000$ | $0.0000$ | Góc đáy phải sân gần |
| **$P_4$ (Near NVZ Left)** | $0.0000$ | $4.5720$ | $0.0000$ | Giao điểm vạch bếp gần và biên trái |
| **$P_5$ (Near NVZ Center)**| $3.0480$ | $4.5720$ | $0.0000$ | Giao điểm vạch bếp gần và vạch giữa |
| **$P_6$ (Near NVZ Right)**| $6.0960$ | $4.5720$ | $0.0000$ | Giao điểm vạch bếp gần và biên phải |
| **$P_{\text{NetLeft}}$** | $0.0000$ | $6.7056$ | $0.9144$ | Cột lưới biên trái |
| **$P_{\text{NetCenter}}$**| $3.0480$ | $6.7056$ | $0.8636$ | Điểm giữa đỉnh lưới |
| **$P_{\text{NetRight}}$** | $6.0960$ | $6.7056$ | $0.9144$ | Cột lưới biên phải |
| **$P_7$ (Far NVZ Left)** | $0.0000$ | $8.8392$ | $0.0000$ | Giao điểm vạch bếp xa và biên trái |
| **$P_8$ (Far NVZ Center)**| $3.0480$ | $8.8392$ | $0.0000$ | Giao điểm vạch bếp xa và vạch giữa |
| **$P_9$ (Far NVZ Right)** | $6.0960$ | $8.8392$ | $0.0000$ | Giao điểm vạch bếp xa và biên phải |
| **$P_{10}$ (Far BL Left)** | $0.0000$ | $13.4112$| $0.0000$ | Góc đáy trái sân xa |
| **$P_{11}$ (Far BL Center)**| $3.0480$ | $13.4112$| $0.0000$ | Giao điểm vạch giữa và đáy xa |
| **$P_{12}$ (Far BL Right)**| $6.0960$ | $13.4112$| $0.0000$ | Góc đáy phải sân xa |

---

#### Hệ Tọa Độ 2: Gốc Tọa Độ Tại Tâm Sân Mặt Đất (Center-of-Court Origin)
Thích hợp cho mô phỏng vật lý 3D đối xứng:
- Gốc $O(0, 0, 0)$: Điểm trên mặt đất ngay dưới tâm lưới ($X=0, Y=0, Z=0$).
- $X \in [-3.048\text{m}, +3.048\text{m}]$ (Trái sang Phải).
- $Y \in [-6.7056\text{m}, +6.7056\text{m}]$ (Near Side sang Far Side).
- Vạch bếp nằm ở: $Y = -2.1336\text{ m}$ và $Y = +2.1336\text{ m}$.
- Vạch đáy nằm ở: $Y = -6.7056\text{ m}$ và $Y = +6.7056\text{ m}$.

---

## 3. QUY TẮC GIAO BÓNG (SERVE RULES) & NGOẠI LỆ VẠCH BẾP

Quy tắc giao bóng trong Pickleball (Mục 4 - Rulebook) có những điểm cốt tử cực kỳ khác biệt với Tennis và bóng bàn:

### 3.1. Vị Trí Người Giao Bóng (Server Position)
- **Quy tắc chân**: Tại thời điểm chạm bóng giao:
  - Ít nhất một chân phải chạm đất phía sau vạch đáy (Baseline).
  - Không được có bất kỳ bộ phận chân nào chạm vào vạch đáy hoặc mặt sân bên trong sân thi đấu.
  - Chân không được chạm vào hoặc vượt quá đường kéo dài giả định của vạch giữa (Centerline) và vạch biên (Sideline).

### 3.2. Hướng Giao Bóng Chéo Sân (Diagonal Crosscourt Serve)
- Người giao bóng đứng ở ô bên phải phát chéo sang ô bên phải của đối thủ (Far Right Service Court).
- Người giao bóng đứng ở ô bên trái phát chéo sang ô bên trái của đối thủ (Far Left Service Court).

---

### 3.3. QUY TẮC BẮT BUỘC: ĐIỂM RƠI BÓNG GIAO & NGOẠI LỆ VẠCH BẾP

> ⚠️ **ĐẶC TẢ SỐNG CÒN CHO CV & DECISION ENGINE:**  
> Trong cú giao bóng, **vạch bếp (Kitchen Line / Non-Volley Zone Line) KHÔNG thuộc về ô giao bóng hợp lệ**.

1. **Bóng giao chạm vào Vạch Bếp (NVZ Line) hoặc rơi vào Khu Vực Bếp (NVZ)**:
   - **KẾT QUẢ: FAULT (LỖI GIAO BÓNG / OUT NGAY LẬP TỨC)**.
   - Kể cả khi bóng chỉ liếm qua mép ngoài (phía tiếp giáp ô giao bóng) của vạch bếp, cú giao bóng vẫn bị tính là **FAULT**.
2. **Bóng giao chạm vào Vạch Biên (Sideline), Vạch Đáy (Baseline), hoặc Vạch Giữa (Centerline)**:
   - **KẾT QUẢ: IN (HỢP LỆ)**.
   - Vạch giữa, vạch biên và vạch đáy đều được tính là nằm trong ô giao bóng.
3. **Bóng giao bay ra ngoài vạch biên hoặc vạch đáy**:
   - **KẾT QUẢ: OUT**.

#### Bảng Tọa Độ Biên Ô Giao Bóng Hợp Lệ (Khi giao chéo từ Near Right sang Far Left):
- Vùng hợp lệ của Far Left Service Court:
  - $X \in [0.0000\text{ m}, 3.0480\text{ m}]$ (Bao gồm cả vạch biên $X=0$ và vạch giữa $X=3.048$).
  - $Y \in (8.8392\text{ m}, 13.4112\text{ m}]$ (**CỰC KỲ QUAN TRỌNG**: Khoảng mở tại $Y=8.8392\text{m}$. Nếu $Y \le 8.8392\text{m} \rightarrow$ **FAULT** vì chạm vạch bếp hoặc rơi vào bếp!).

---

### 3.4. Quy Tắc Bóng Chạm Mép Lưới Khi Giao Bóng (Net Cord / No-Let Rule)
- Kể từ bản sửa đổi luật USA Pickleball năm 2021: **QUY TẮC "LET SERVE" ĐÃ BỊ LOẠI BỎ HOÀN TOÀN**.
- Nếu bóng giao chạm mép lưới (Net Cord), băng qua lưới và rơi vào ô giao bóng hợp lệ của đối phương $\rightarrow$ **BÓNG SỐNG (IN / LIVE BALL)**, trận đấu tiếp tục bình thường, **KHÔNG phát lại**.
- Nếu bóng chạm lưới rồi rơi vào khu vực bếp hoặc vạch bếp của đối phương $\rightarrow$ **FAULT**.

---

## 4. QUY TẮC TRONG PHA BÓNG SỐNG (LIVE RALLY RULES)

Sau khi cú giao bóng và cú trả giao bóng được thực hiện hợp lệ, pha bóng bước vào trạng thái đánh bóng tự do (Live Rally).

### 4.1. Quy Tắc In / Out Trong Pha Bóng Sống
- **Quy tắc vạch biên & vạch đáy**:
  - Nếu bất kỳ phần nào của quả bóng tiếp xúc với bất kỳ phần nào của vạch biên hoặc vạch đáy $\rightarrow$ **IN**.
  - Chỉ khi bóng nảy hoàn toàn bên ngoài mép ngoài của các vạch bao quanh sân $\rightarrow$ **OUT**.
- **Quy tắc khu vực bếp trong pha bóng sống**:
  - Khi bóng đang trong pha bóng sống (Live Rally), quả bóng rơi vào khu vực bếp hoặc chạm vạch bếp $\rightarrow$ **HOÀN TOÀN HỢP LỆ (IN)**!
  - Đối thủ hoàn toàn được phép để bóng nảy 1 lần trong bếp rồi đánh trả sang sân đối diện.

---

### 4.2. Quy Tắc Hai Lần Nảy (Two-Bounce Rule / Rule 4.A)
Quy tắc đặc trưng nhất của Pickleball nhằm hạn chế lợi thế giao bóng lên lưới:
1. **Lần nảy 1 (Bounce 1 - Đội nhận bóng)**: Sau khi bóng giao qua lưới, Đội nhận giao bóng **BẮT BUỘC** phải để bóng nảy 1 lần trên sân mình trước khi đánh trả (Return of Serve). Cấm đánh vô-lê cú này!
2. **Lần nảy 2 (Bounce 2 - Đội giao bóng)**: Sau khi Đội nhận đánh bóng trả về, Đội giao bóng **BẮT BUỘC** phải để bóng nảy 1 lần trên sân mình trước khi đánh trả (Third Shot). Cấm đánh vô-lê cú này!
3. **Từ cú đánh thứ 4 trở đi (Fourth Shot and beyond)**: Cả hai đội được quyền đánh vô-lê (Volley - đánh bóng trên không khi chưa chạm đất) hoặc tiếp tục đánh bóng nảy (Groundstroke).

> **Phán Quyết Lỗi**: Nếu bất kỳ cầu thủ nào đánh vô-lê bóng ở Cú thứ 2 (Return) hoặc Cú thứ 3 (Third shot) $\rightarrow$ **FAULT ngay lập tức**; bên vi phạm thua pha bóng đó.

---

### 4.3. Lỗi Vô-lê Trong Khu Vực Bếp (Kitchen / NVZ Volley Fault - Rule 9)
Khu vực Non-Volley Zone (NVZ) sinh ra để ngăn chặn người chơi áp sát lưới đập bóng trực tiếp:
- **Hành vi phạm lỗi**: Người chơi thực hiện cú đánh **Vô-lê (Volley - khi bóng chưa nảy)** khi:
  1. Đang có bất kỳ bàn chân hoặc bộ phận cơ thể nào chạm vào bên trong khu vực bếp hoặc chạm vào **Vạch Bếp (NVZ Line)**.
  2. Đà di chuyển (Momentum) sau khi đánh vô-lê (dù tiếp xúc bóng trên không ngoài bếp) khiến cầu thủ bước chân, ngã, hoặc chạm chân vào vạch bếp/bên trong bếp.
  3. Bất kỳ vật dụng nào mang trên người (vợt, mũ, kính, khăn lau) rơi vào khu vực bếp trong quá trình thực hiện vô-lê.
- **Hành vi HỢP LỆ**:
  - Cầu thủ đứng trong bếp, bóng bay sang và **NẢY TRONG BẾP**, cầu thủ đánh bóng sau khi bóng đã nảy (Dink/Groundstroke) $\rightarrow$ **HOÀN TOÀN HỢP LỆ (LEGAL)**!

---

### 4.4. Điều Kiện Bóng Chết (Dead Ball / Rally End Triggers)
Một pha bóng kết thúc ngay khi xảy ra một trong các điều kiện sau:
1. **Bóng nảy 2 lần liên tiếp (Double Bounce)** trên cùng một nửa sân của một đội mà chưa được đánh trả.
2. **Bóng ra ngoài sân (Out of bounds)**: Bóng chạm mặt đất ngoài vạch biên/đáy, hoặc chạm vật cản bên ngoài (hàng rào, trần nhà, người ngoài sân).
3. **Bóng không qua lưới (Net Failure)**: Bóng đập vào lưới rơi lại sân mình hoặc vướng vào lưới.
4. **Bóng chạm người cầu thủ (Body Touch Fault)**: Bóng chạm vào người hoặc quần áo cầu thủ trước khi nảy (trừ khi chạm vào bàn tay cầm vợt dưới cổ tay).
5. **Lỗi quy tắc (Rule Fault)**: Lỗi giao bóng chạm vạch bếp, lỗi Two-Bounce, lỗi vô-lê trong bếp.

---

## 5. MÁY TRẠNG THÁI PHA BÓNG & THỂ THỨC TRẬN ĐẤU (RALLY STATE MACHINE)

Để lập trình `RallyEngine.swift` mạch lạc và không bị xung đột logic thời gian thực, kiến trúc máy trạng thái (State Machine) được chuẩn hóa như sau:

### 5.1. Sơ Đồ Chuyển Trạng Thái (State Transition Diagram)

```
        +-------------------------------------------------------+
        |                                                       |
        v                                                       |
 [WAITING_FOR_SERVE] --(Event: SERVE_HIT)--> [SERVE_IN_FLIGHT]   |
        |                                         |             |
        | (Manual Reset / Timeout)                |             |
        +-----------------------------------+     |             |
                                            |     |             |
                                            v     v             |
                         (Event: SERVE_BOUNCE_LEGAL)            |
                                            |                   |
                                            v                   |
                                       [IN_PLAY]                |
                                            |                   |
                +---------------------------+-------------------+
                |                           |                   |
        (FAULT_DETECTED)           (BALL_OUT / 2_BOUNCES)  (NET_FAIL)
                |                           |                   |
                +---------------------+-----+-------------------+
                                      |
                                      v
                                 [RALLY_END]
                                      |
                           (Score / Switch Server)
                                      |
                                      +------------------------->
```

---

### 5.2. Định Nghĩa Các Trạng Thái (States)

1. `WAITING_FOR_SERVE`:
   - Các cầu thủ đã vào vị trí theo điểm số hiện tại.
   - Đồng hồ pha bóng dừng ở `00:00.0`.
   - Lượt đổi hướng (Shot count) = 0.
   - Hệ thống Computer Vision chờ đợi hành vi vung vợt phát bóng của người giao bóng được chỉ định.
2. `SERVE_IN_FLIGHT`:
   - Quả bóng đã rời mặt vợt người giao bóng, đang bay qua lưới sang nửa sân đối diện.
   - Bắt đầu tính giờ pha bóng (Rally Duration).
   - Hệ thống chuẩn bị điểm nảy đầu tiên để kiểm tra điều kiện giao bóng khắt khe.
3. `IN_PLAY`:
   - Cú giao bóng đã nảy hợp lệ vào ô chéo sân và cú trả giao bóng bắt đầu.
   - Đếm lượt đổi hướng (Shot Exchanges / Rally Count) mỗi khi bóng vượt qua mặt phẳng lưới.
   - Liên tục theo dõi vị trí cổ chân người chơi (Player Tracking) so sánh với vạch bếp khi có sự kiện đánh vô-lê.
4. `RALLY_END`:
   - Trạng thái dừng pha bóng khi phát hiện bóng chết hoặc phạm quy.
   - Ghi nhận: Đội thắng pha, điểm số mới, tốc độ bóng cao nhất (Peak Speed), số mét di chuyển của từng cầu thủ trong pha.
   - Kích hoạt cửa sổ VAR Replay 5 giây nếu có tình huống tranh cãi sát vạch.

---

### 5.3. Bảng Sự Kiện & Điều Kiện Chuyển Đổi (State Transitions)

| Từ Trạng Thái | Sự Kiện (Trigger) | Điều Kiện Kiểm Tra (Guards) | Trạng Thái Đích | Hành Động Kèm Theo (Actions) |
|:---|:---|:---|:---|:---|
| `WAITING_FOR_SERVE` | `SERVE_HIT` | Người đánh đúng là Server, vị trí chân ngoài Baseline | `SERVE_IN_FLIGHT` | Bắt đầu bấm giờ rally; gán `shotCount = 1` |
| `WAITING_FOR_SERVE` | `WRONG_SERVER_HIT` | Người đánh không đúng lượt giao bóng | `RALLY_END` | Báo lỗi `FAULT_WRONG_SERVER`, điểm cho đối thủ |
| `SERVE_IN_FLIGHT` | `BALL_BOUNCE` | Điểm nảy rơi vào NVZ hoặc chạm NVZ Line ($Y \le Y_{\text{NVZ}}$) | `RALLY_END` | Phán quyết `FAULT_SHORT_SERVE` (Giao vào bếp); Đổi giao bóng |
| `SERVE_IN_FLIGHT` | `BALL_BOUNCE` | Điểm nảy nằm ngoài vạch biên/đáy ô chéo | `RALLY_END` | Phán quyết `OUT_SERVE`; Đổi giao bóng |
| `SERVE_IN_FLIGHT` | `BALL_BOUNCE` | Điểm nảy nằm trọn vẹn trong ô giao bóng chéo ($Y > Y_{\text{NVZ}}$) | `IN_PLAY` | Phán quyết `SERVE_IN`; Đếm `bounceCount = 1` |
| `SERVE_IN_FLIGHT` | `PLAYER_HIT` | Đội nhận đánh bóng khi bóng CHƯA nảy | `RALLY_END` | Phán quyết `FAULT_TWO_BOUNCE_RECEIVER` (Vô-lê trả giao bóng) |
| `IN_PLAY` | `BALL_CROSS_NET` | Quỹ đạo bóng vượt qua mặt phẳng $Y_{\text{Net}}$ | `IN_PLAY` | Tăng `shotExchanges += 1` |
| `IN_PLAY` | `PLAYER_HIT` | Đội giao bóng vô-lê ở Cú thứ 3 khi bóng chưa nảy | `RALLY_END` | Phán quyết `FAULT_TWO_BOUNCE_SERVER`; Kết thúc pha |
| `IN_PLAY` | `PLAYER_HIT` | Cầu thủ đánh vô-lê trong khi chân chạm bếp hoặc trớn chạm bếp | `RALLY_END` | Phán quyết `FAULT_KITCHEN_VOLLEY`; Kết thúc pha |
| `IN_PLAY` | `BALL_BOUNCE` | Bóng nảy lần thứ 2 trên cùng một nửa sân | `RALLY_END` | Phán quyết `DOUBLE_BOUNCE`; Điểm thuộc về đối thủ |
| `IN_PLAY` | `BALL_BOUNCE` | Điểm nảy nằm ngoài mép ngoài của các vạch bao sân | `RALLY_END` | Phán quyết `OUT`; Điểm thuộc về đối thủ |
| `IN_PLAY` | `NET_COLLISION`| Bóng đập lưới không sang được sân đối phương | `RALLY_END` | Phán quyết `NET_FAULT`; Điểm thuộc về đối thủ |
| `RALLY_END` | `RESET_FOR_SERVE`| Trọng tài/Người dùng xác nhận, cầu thủ sẵn sàng | `WAITING_FOR_SERVE`| Cập nhật điểm, xoá cache pha bóng, chờ phát bóng mới |

---

### 5.4. Thể Thức Tính Điểm & Cơ Chế Đổi Lượt Giao Bóng (Scoring Mechanics)

PickleVision mặc định hỗ trợ thể thức thi đấu chính thức **Side-Out Scoring** (Chỉ đội giao bóng mới có thể ghi điểm) và cấu hình mở rộng **Rally Scoring**:

#### 1. Đánh Đôi (Doubles - Quy tắc 3 con số: `4 - 3 - 1` hoặc `4 - 3 - 2`):
- Điểm số được công bố gồm 3 phần:  
  $$\text{Điểm đội giao} - \text{Điểm đội nhận} - \text{Số thứ tự người giao (1 hoặc 2)}$$
- **Khởi đầu trận đấu (Đặc thù)**:  
  Đội giao bóng đầu tiên chỉ có **1 lượt phát bóng** (gọi điểm là `0 - 0 - 2`). Khi mất lượt này, quyền giao bóng lập tức chuyển sang đội đối phương (Side-Out).
- **Các lượt tiếp theo**:  
  Mỗi đội có 2 lượt phát bóng (Server 1 phát trước; khi mất lượt thì Server 2 phát tiếp; khi Server 2 mất lượt $\rightarrow$ Side-Out sang đội kia).
- **Vị trí giao bóng theo điểm số**:
  - Khi điểm đội giao là **Chẵn** ($0, 2, 4, \dots$): Server đứng ở ô bên Phải.
  - Khi điểm đội giao là **Lẻ** ($1, 3, 5, \dots$): Server đứng ở ô bên Trái.

#### 2. Đánh Đơn (Singles - Quy tắc 2 con số: `4 - 3`):
- Không có số thứ tự Server.
- Khi điểm của người giao bóng là Chẵn $\rightarrow$ Giao bóng từ ô bên Phải.
- Khi điểm của người giao bóng là Lẻ $\rightarrow$ Giao bóng từ ô bên Trái.
- Khi người giao bóng thua pha $\rightarrow$ Mất quyền giao bóng lập tức chuyển sang đối thủ (Side-out).

---

## 6. BẢNG PHÁT HIỆN TÍNH NĂNG (FEATURES DISCOVERED)

Theo quy chuẩn Specification Miner, toàn bộ các quy tắc và chức năng nghiệp vụ được trích xuất và chuẩn hóa vào bảng sau:

| # | Phân Loại | Tính Năng | Mô Tả Nghiệp Vụ | Dữ Liệu Đầu Vào (Inputs) | Dữ Liệu Đầu Ra (Outputs) | Hành Vi Khi Lỗi / Sai Phạm | Nguồn Quy Chuẩn |
|---|---|---|---|---|---|---|---|
| **1** | Geometry | Court Dimension Modeling | Dựng lưới tọa độ thực tế 2D/3D của sân Pickleball | Chiều dài $13.4112\text{m}$, Rộng $6.096\text{m}$, NVZ $2.1336\text{m}$ | Polygon tọa độ chuẩn $(X, Y, Z)$ cho 12 chốt sân | Báo lỗi hiệu chuẩn nếu góc lệch vượt ngưỡng $\pm 10^\circ$ | USAP Rulebook Mục 2.A |
| **2** | Calibration | DLT Homography Mapping | Chuyển đổi qua lại giữa tọa độ Pixel Camera và Mét thực tế | 4 góc sân từ người dùng hoặc auto-detect | Ma trận $H_{3 \times 3}$ khả nghịch | Lỗi `SingularMatrix` nếu 4 điểm đồng tuyến | Spec Kiến Trúc §2 |
| **3** | Serve | Serve Placement Validation | Kiểm tra điểm rơi bóng giao chéo sân | Tọa độ tiếp đất $(X_b, Y_b)$, Ô giao bóng chỉ định | Phán quyết `IN` hoặc `FAULT` | Nếu chạm vạch bếp hoặc vào ô bếp $\rightarrow$ `FAULT_SHORT` | USAP Rulebook Mục 4.A |
| **4** | Serve | NVZ Line Exclusion on Serve | Quy tắc vạch bếp KHÔNG thuộc ô giao bóng | Điểm tiếp xúc của bóng với mặt sân | `isTouchKitchenLine: Bool` | Bất kỳ tiếp xúc nào với vạch bếp $\rightarrow$ `FAULT` | USAP Rule 4.A.2 & 4.M |
| **5** | Serve | Boundary Line Inclusion on Serve | Vạch biên, vạch đáy, vạch giữa thuộc ô giao bóng | Tọa độ điểm chạm bóng | `isTouchBoundary: Bool` | Tiếp xúc vạch biên/đáy/giữa $\rightarrow$ `IN` | USAP Rule 4.A.2 |
| **6** | Serve | No-Let Service Rule | Bỏ luật phát lại khi bóng liếm lưới | Sự kiện chạm lưới + Điểm rơi sau lưới | `isLiveBall: Bool` | Nếu rơi vào ô hợp lệ $\rightarrow$ Tiếp tục; vào bếp $\rightarrow$ `FAULT` | USAP Rulebook 2021 Update |
| **7** | Rally | Two-Bounce Rule Enforcement | Kiểm tra bắt buộc 2 lần nảy trước khi vô-lê | Số thứ tự chạm bóng (`shotIndex`), Loại cú đánh (Volley/Ground) | Hợp lệ hoặc `FAULT_TWO_BOUNCE` | Vô-lê ở Cú 2 hoặc Cú 3 $\rightarrow$ Thua pha bóng ngay | USAP Rule 4.A |
| **8** | Rally | NVZ Kitchen Volley Fault | Phát hiện cầu thủ giẫm bếp khi vô-lê | Tọa độ 2 cổ chân người chơi, Thời điểm tiếp xúc bóng | Hợp lệ hoặc `FAULT_KITCHEN_VOLLEY` | Cổ chân chạm vạch bếp hoặc trớn ngã vào bếp $\rightarrow$ `FAULT` | USAP Rule 9.B & 9.C |
| **9** | Rally | Live Ball In-Kitchen Validity | Bóng rơi trong bếp ở pha bóng thường là hợp lệ | Tọa độ điểm nảy bóng $(X, Y)$ khi `RallyState == .inPlay` | Phán quyết `IN (Playable)` | Không có lỗi, bóng tiếp tục sống | USAP Rule 2.B.3 |
| **10**| Rally | Boundary Line In/Out Judgement | Phán quyết bóng rơi trong hay ngoài vạch biên | Bán kính bóng $R=3.7\text{cm}$, Vị trí nảy $(X, Y)$ | Phán quyết `IN` hoặc `OUT` | Bóng rơi trọn vẹn ngoài mép ngoài $\rightarrow$ `OUT` | USAP Rule 6.A |
| **11**| State | Rally State Transition | Quản lý chuyển đổi trạng thái vòng đời pha bóng | Tín hiệu chạm bóng, nảy bóng, chạm lưới, lỗi | Trạng thái mới, Đồng hồ pha, Lượt đổi hướng | Tự động chuyển về `RALLY_END` khi bóng chết | Spec Kiến Trúc §5 |
| **12**| Metrics | Ball Speed Calculation | Tính tốc độ tức thời của quả bóng | Khoảng cách 3D $\Delta d$, Thời gian bay $\Delta t$ | Tốc độ km/h, Tốc độ đỉnh (Peak km/h) | Lọc bỏ vector phi thực tế ($> 120\text{ km/h}$) | Spec Kiến Trúc §4 |
| **13**| Metrics | Player Distance Tracking | Đo quãng đường di chuyển của từng cầu thủ | Chuỗi tọa độ tiếp đất cổ chân theo thời gian | Quãng đường pha (m), Quãng đường trận (m) | Bộ lọc rung lắc $\Delta d < 0.05\text{m}$ | Spec Kiến Trúc §3 |
| **14**| Scoring | Doubles Side-Out Engine | Tính điểm đánh đôi 3 con số và đảo người giao | Kết quả pha bóng (Giao thắng / Giao thua) | Điểm số mới (`S-R-ServerNumber`), Ô đứng tiếp theo | Hết 2 lượt giao $\rightarrow$ Chuyển quyền giao (Side-Out) | USAP Rule 4.B |

---

## 7. BẢNG TRƯỜNG HỢP BIÊN & TÌNH HUỐNG PHỨC TẠP (EDGE CASES)

| # | Tính Năng Liên Quan | Trường Hợp Đầu Vào (Input Scenario) | Hành Vi Chuẩn Quan Sát Được / Phán Quyết | Cơ Sở Luật USA Pickleball |
|---|---|---|---|---|
| **E1** | Giao bóng (Serve) | Bóng giao chạm mép ngoài của vạch bếp (tiếp giáp ô giao bóng) chỉ 1 milimet | **FAULT (OUT)**. Toàn bộ bề rộng $5.08\text{cm}$ của vạch bếp được coi là khu vực cấm khi giao bóng. | USAP Rule 4.A.2: "The serve must clear the net and the NVZ, including the NVZ lines." |
| **E2** | Giao bóng (Serve) | Bóng giao đập trúng mép lưới (Net cord), đổi hướng rơi vào trong ô giao bóng hợp lệ | **IN (BÓNG SỐNG)**. Trận đấu tiếp tục, người nhận phải đánh trả sau khi bóng nảy. | USAP Rule 4.O: Không còn luật Let serve. Bóng chạm lưới rơi đúng ô là bóng sống. |
| **E3** | Giao bóng (Serve) | Bóng giao chạm mép lưới rồi rơi trúng vạch bếp đối phương | **FAULT**. Dù chạm lưới nhưng điểm rơi vi phạm vạch bếp $\rightarrow$ Mất quyền giao bóng. | USAP Rule 4.A.2. |
| **E4** | Giao bóng (Serve) | Bóng giao tiếp xúc mép ngoài của vạch đáy (Baseline) hoặc vạch biên (Sideline) | **IN**. Vạch biên và vạch đáy thuộc về ô giao bóng hợp lệ. | USAP Rule 6.A: "A ball contacting any part of a line is considered in." |
| **E5** | Giao bóng (Serve) | Chân người giao bóng nhấc lên khỏi mặt đất hoàn toàn (nhảy giao bóng) khi chạm bóng | **FAULT (Service Foot Fault)**. Luật yêu cầu ít nhất một chân phải tiếp xúc mặt đất phía sau vạch đáy khi tiếp xúc bóng. | USAP Rule 4.A.4.a. |
| **E6** | Trả giao bóng | Người nhận bóng đánh vô-lê trực tiếp khi bóng giao vừa bay qua lưới (chưa nảy) | **FAULT (Two-Bounce Fault)**. Đội nhận mất điểm ngay lập tức, đội giao bóng ghi điểm. | USAP Rule 4.A: "Two-Bounce Rule". |
| **E7** | Cú đánh thứ 3 | Đội giao bóng lao lên lưới vô-lê ngay cú trả giao bóng của đối thủ (cú thứ 3 chưa nảy) | **FAULT (Two-Bounce Fault)**. Đội giao bóng mất lượt giao bóng (hoặc mất điểm). | USAP Rule 4.A. |
| **E8** | Vô-lê trong bếp | Cầu thủ đứng ngoài vạch bếp, nhảy lên vô-lê bóng trên không, đánh xong tiếp đất rơi chân vào vạch bếp | **FAULT (NVZ Momentum Fault)**. Đà di chuyển sau cú vô-lê làm chạm vạch bếp là phạm quy, kể cả khi bóng đã chạm đất bên sân đối phương trước đó. | USAP Rule 9.B & 9.C. |
| **E9** | Vô-lê trong bếp | Cầu thủ đánh vô-lê hoàn hảo ngoài bếp, nhưng mũ hoặc kính rơi vào trong bếp | **FAULT**. Bất kỳ vật dụng nào rơi vào bếp trong hoặc sau cú vô-lê đều bị xử phạt lỗi. | USAP Rule 9.D. |
| **E10**| Bóng sống trong bếp | Bóng đối phương đánh sang rơi nảy 1 lần trong bếp, cầu thủ bước cả 2 chân vào bếp đánh trả | **HỢP LỆ (IN / LEGAL)**. Cầu thủ được phép ở trong bếp bất kỳ lúc nào nếu bóng đã nảy trước khi đánh. | USAP Rule 9.A & 9.E. |
| **E11**| Bóng chạm thân vợt | Cầu thủ đỡ bóng bị trúng mép vợt (edge guard) hoặc tay cầm vợt bay sang sân hợp lệ | **HỢP LỆ (LEGAL)**. Chạm vào bất kỳ phần nào của vợt hoặc bàn tay dưới cổ tay đang cầm vợt đều hợp lệ. | USAP Rule 7.J. |
| **E12**| Bóng bay vòng ngoài cột lưới | Cầu thủ đánh bóng bay vòng quanh bên ngoài cột lưới vào sân đối phương ở độ cao thấp hơn lưới (Around The Post - ATP) | **HỢP LỆ (LEGAL)**. Cú đánh ATP hoàn toàn hợp lệ miễn là bóng rơi vào trong sân đối phương. | USAP Rule 11.M. |

---

## 8. ĐẶC TẢ KỸ THUẬT DÀNH CHO BACKEND, FRONTEND & TESTER

### 8.1. Hướng Dẫn Kỹ Thuật Cho Backend Coder

#### 1. Kiểm Tra Điểm Rơi In / Out Bằng Thuật Toán Hình Học (Point-In-Polygon):
Để phán quyết tự động, Backend triển khai hàm phán quyết với bán kính bóng nhựa Pickleball ($r \approx 0.037\text{ m}$):
- **Đối với Pha Giao Bóng (Serve)**:
  ```swift
  func judgeServeBounce(point: CGPoint, targetCourt: ServiceCourtBox) -> CallDecision {
      // 1. Kiểm tra vạch bếp (Kitchen Exclusion):
      // Nếu tung độ Y của bóng nằm trong hoặc chạm vạch bếp (sai số dung sai tiếp xúc bóng r)
      if point.y <= (targetCourt.nvzLineY + ballRadius) {
          return .fault(reason: .hitKitchenLineOrZone)
      }
      // 2. Kiểm tra các biên còn lại (Inclusion: Baseline, Sidelines, Centerline)
      if point.x >= (targetCourt.minX - ballRadius) &&
         point.x <= (targetCourt.maxX + ballRadius) &&
         point.y <= (targetCourt.maxY + ballRadius) {
          return .inPlay
      }
      return .out(reason: .beyondBoundaries)
  }
  ```

#### 2. Kiểm Tra Vô-lê Khu Vực Bếp (Kitchen Volley Verification):
- Khi `PlayerTrackerService` phát hiện một cú chạm bóng mà quỹ đạo bóng không có điểm đổi chiều gia tốc $\frac{d^2y}{dt^2} > 0$ trước đó (tức là đánh vô-lê):
  - Lấy tọa độ chân của cầu thủ đó tại các khung hình $t, t+1, t+2, \dots, t+N$ (khoảng 1.0 giây sau cú đánh để tính trớn momentum).
  - Nếu $\min(Y_{\text{ankle}}) \le Y_{\text{NVZ}} + \text{margin}$ đối với sân xa hoặc $\max(Y_{\text{ankle}}) \ge Y_{\text{NVZ}} - \text{margin}$ đối với sân gần $\rightarrow$ Kích hoạt `FAULT_KITCHEN_VOLLEY`.

---

### 8.2. Hướng Dẫn Kỹ Thuật Cho Frontend Coder

1. **Minimap 2D (CourtMiniMapView.swift)**:
   - Tỷ lệ khung sân: Rộng $6.096\text{ m}$ / Dài $13.4112\text{ m} \approx 1 : 2.2$.
   - Vẽ rõ vùng Bếp (NVZ) bằng mảng màu phân biệt (ví dụ: Xanh ngọc hoặc phủ mờ $15\%$) để người xem dễ phân biệt với 2 ô giao bóng.
   - Vạch bếp phải được kẻ rõ nét và nhấp nháy đỏ khi có lỗi `KITCHEN_FAULT`.
2. **Kính Lúp Phán Quyết VAR (InstantReplayVARView.swift)**:
   - Khi bóng rơi sát vạch ($\le 0.1\text{ m}$): Tự động hiển thị vòng tròn zoom $3\times$ (Magnifying Loupe) tại điểm tiếp xúc.
   - Nếu là pha giao bóng chạm vạch bếp: Đóng dấu nhãn chữ **FAULT / OUT (Màu Đỏ)** to rõ.
   - Nếu là bóng chạm vạch biên/đáy: Đóng dấu nhãn chữ **IN (Màu Xanh Lá)**.

---

### 8.3. Hướng Dẫn Kiểm Thử Cho Tester (XCTest Suite Specs)

Tester cần thiết lập các bài kiểm thử tự động với dữ liệu tọa độ mốc chuẩn:
1. `testServe_HittingKitchenLine_MustReturnFault`:
   - Input: $X = 1.5\text{m}, Y = 8.8392\text{m}$ (Ngay trên vạch bếp xa).
   - Expected Output: `.fault(reason: .hitKitchenLineOrZone)`.
2. `testServe_HittingBaseline_MustReturnIn`:
   - Input: $X = 1.5\text{m}, Y = 13.4112\text{m}$ (Ngay trên vạch đáy).
   - Expected Output: `.inPlay`.
3. `testLiveRally_HittingKitchenZone_MustReturnIn`:
   - Input: $X = 2.0\text{m}, Y = 5.0\text{m}$ trong pha bóng sống (`state == .inPlay`).
   - Expected Output: `.inPlay`.
4. `testTwoBounceRule_VolleyOnReturn_MustTriggerFault`:
   - Chuỗi sự kiện: ServeHit $\rightarrow$ Receiver Volley (chưa có Bounce).
   - Expected Output: `RallyState == .rallyEnd` kèm lỗi `twoBounceViolation`.
5. `testHomographyPrecision_ErrorUnderTwoCentimeters`:
   - Kiểm tra tính toán ma trận $H$ từ 4 điểm pixel mẫu, chiếu ngược về tọa độ mét thực tế, sai số Euclidean $\le 0.02\text{ m}$.

---

## LỜI KẾT CỦA CỐ VẤN THỂ THỨC
Bộ quy tắc chuẩn USA Pickleball trên đây là "kim chỉ nam" bắt buộc cho hệ thống logic của PickleVision. Bất kỳ sự sai lệch nào (đặc biệt là nhầm lẫn giữa quy tắc vạch bếp khi giao bóng và khi đánh bóng sống) đều sẽ làm sai lệch bản chất của ứng dụng hỗ trợ VAR và phân tích chiến thuật thể thao chuyên nghiệp. Các đội ngũ hãy bám sát từng tọa độ và điều kiện rẽ nhánh đã được kiểm chứng này!
