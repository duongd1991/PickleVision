## 2026-11-05T10:01:23Z
[Message] timestamp=2026-11-05T10:01:23Z sender=c4a80aac-c6f3-45ce-a5dc-a550acba35ac priority=MESSAGE_PRIORITY_HIGH content=Bạn là Athletic Coach trong đội ngũ AI Agent phát triển ứng dụng PickleVision Native iOS.
Nhiệm vụ của bạn: Khảo sát, phân tích chuyên sâu và đặc tả toàn bộ quy tắc, thể thức và luật thi đấu chuẩn USA Pickleball để đội ngũ kỹ thuật (Backend, Frontend, Tester) thiết kế và lập trình chính xác 100% logic ứng dụng.

Thư mục làm việc của bạn: c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\coach_survey\
Các tài liệu bắt buộc đọc trước khi phân tích:
- c:\Users\quantri\Downloads\AntiGravity\CheckPoint\.agents\teamwork\ORIGINAL_REQUEST.md
- C:\Users\quantri\.gemini\antigravity\brain\a4911cc8-4776-4995-b0e0-c96d5d2138a7\pickleball_app_specification.md

Yêu cầu nội dung báo cáo cố vấn thể thức (coach_rules_report.md):
1. Kích thước sân chuẩn USA Pickleball:
   - Chiều dài: 13.41m (44 ft), chiều rộng: 6.10m (20 ft).
   - Non-Volley Zone (NVZ / Khu vực bếp): Cách lưới 2.13m (7 ft) mỗi bên.
   - Chiều cao lưới: 0.914m (36 in) ở 2 cột biên, 0.864m (34 in) ở giữa sân.
   - Tọa độ chuẩn 2D/3D của tất cả các vạch: Baseline (vạch đáy), Sidelines (vạch biên), Centerline (vạch giữa), Kitchen line (vạch bếp).
2. Quy tắc giao bóng (Serve Rules):
   - Vị trí đứng khi giao bóng, giao bóng chéo sân (diagonal).
   - Điểm rơi bóng khi giao bóng: Phải vượt qua vạch bếp và rơi vào ô giao bóng chéo đối diện.
   - QUY TẮC BẮT BUỘC: Nếu bóng giao chạm vào vạch bếp (Kitchen Line) hoặc rơi trong khu vực bếp -> FAULT (OUT). Khác hoàn toàn với vạch biên/đáy!
   - Bóng chạm vạch biên, vạch đáy hoặc vạch giữa sân khi giao bóng -> IN.
3. Quy tắc trong pha đánh bóng thông thường (Live Rally):
   - Bóng rơi trong khu vực bếp hoặc chạm vạch bếp trong pha bóng bình thường -> IN (Hợp lệ).
   - Bóng chạm bất kỳ mép ngoài/trong của vạch biên hoặc vạch đáy -> IN.
   - Bóng rơi hoàn toàn ngoài các vạch biên/đáy -> OUT.
   - Quy tắc 2 lần nảy (Two-Bounce Rule) khi bắt đầu giao bóng và trả giao bóng.
   - Lỗi giẫm chân vào bếp khi bắt vô-lê (Kitchen Volley Fault).
4. Máy trạng thái pha bóng (Rally State Machine):
   - Các trạng thái: CHỜ GIAO BÓNG (WAITING_FOR_SERVE) -> ĐANG ĐÁNH (IN_PLAY) -> KẾT THÚC PHA (RALLY_END).
   - Điều kiện bắt đầu và kết thúc pha bóng (bóng chết: nảy 2 lần, bay ra ngoài, chạm lưới không qua, người chơi phạm lỗi).
   - Quy tắc tính điểm và lượt đổi hướng cầu (shot exchanges).
5. Yêu cầu bàn giao:
   - Ghi báo cáo chi tiết vào file `coach_rules_report.md` tại thư mục làm việc của bạn.
   - Tạo `handoff.md` tóm tắt toàn bộ kết quả, công thức và quy tắc then chốt gửi về cho orchestrator.
   - Sau khi hoàn thành, dùng send_message để thông báo kết quả cho orchestrator.
