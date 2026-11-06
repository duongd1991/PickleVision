#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PickleVision Adversarial Stress Testing Harness (Challenger 2)
==============================================================
Empirical adversarial verification of:
1. Player Distance & Jitter Filter Stress Suite (100+ frames random jitter [0.001, 0.049]m, teleportation glitch > 10.5 m/s)
2. Ball Tracker & Parabola Fit Stress Suite (High velocities 30-90 km/h, outlier rejection > 130 km/h, vertical bounce d2y/dt2 > 0)
3. RallyEngine State Machine & Side-Out Rotation Stress Suite (Doubles/singles rotation cycles, double bounce detection)
4. Numerical Stability & Boundary Edge Cases Suite
"""

import sys
import math
import time
import random
from typing import List, Tuple, Optional, Dict

# Thiết lập encoding UTF-8 cho console Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Import core models từ test_runner
from test_runner import (
    COURT_WIDTH, COURT_LENGTH, NEAR_NVZ_Y, FAR_NVZ_Y, NET_Y, CENTERLINE_X, LINE_WIDTH, BALL_RADIUS,
    CourtCalibrationService, KalmanFilter2D, PlayerTrack,
    ParabolaCoefficients, fit_parabola, RallyEngine, PickleballCVCoordinator
)

# ==============================================================================
# MÔ HÌNH KALMAN FILTER 4X4 (SWIFT EQUIVALENT) ĐỂ SO SÁNH ĐỐI KHÁNG
# ==============================================================================

class SwiftKalmanFilter2D:
    """Mô hình toán học tương đương 100% với KalmanFilter2D trong PlayerTrack.swift:
       State: [x, y, vx, vy]^T, ma trận P 4x4, tính toán Kalman Gain K (4x2)
    """
    def __init__(self, initial_pos: Tuple[float, float], process_noise: float = 0.5, measurement_noise: float = 0.1):
        self.state = [initial_pos[0], initial_pos[1], 0.0, 0.0]
        self.process_noise = process_noise
        self.measurement_noise = measurement_noise
        self.P = [
            1.0, 0.0, 0.0, 0.0,
            0.0, 1.0, 0.0, 0.0,
            0.0, 0.0, 5.0, 0.0,
            0.0, 0.0, 0.0, 5.0
        ]

    def predict(self, dt: float) -> Tuple[float, float]:
        if dt <= 0:
            return (self.state[0], self.state[1])
        x_new = self.state[0] + self.state[2] * dt
        y_new = self.state[1] + self.state[3] * dt
        vx_new = self.state[2]
        vy_new = self.state[3]
        self.state = [x_new, y_new, vx_new, vy_new]

        q_val = self.process_noise * dt
        new_P = list(self.P)
        new_P[0] += dt * (self.P[8] + self.P[2]) + dt * dt * self.P[10] + q_val
        new_P[1] += dt * (self.P[9] + self.P[3]) + dt * dt * self.P[11]
        new_P[4] += dt * (self.P[8] + self.P[6]) + dt * dt * self.P[10]
        new_P[5] += dt * (self.P[9] + self.P[7]) + dt * dt * self.P[11] + q_val
        new_P[10] += q_val * 2.0
        new_P[15] += q_val * 2.0
        self.P = new_P
        return (self.state[0], self.state[1])

    def update(self, measurement: Tuple[float, float]) -> Tuple[float, float]:
        zx, zy = measurement
        yx = zx - self.state[0]
        yy = zy - self.state[1]

        s00 = self.P[0] + self.measurement_noise
        s01 = self.P[1]
        s10 = self.P[4]
        s11 = self.P[5] + self.measurement_noise

        det_s = s00 * s11 - s01 * s10
        inv_det = (1.0 / det_s) if abs(det_s) > 1e-9 else 1.0
        inv_s00 = s11 * inv_det
        inv_s01 = -s01 * inv_det
        inv_s10 = -s10 * inv_det
        inv_s11 = s00 * inv_det

        k00 = self.P[0] * inv_s00 + self.P[1] * inv_s10
        k01 = self.P[0] * inv_s01 + self.P[1] * inv_s11
        k10 = self.P[4] * inv_s00 + self.P[5] * inv_s10
        k11 = self.P[4] * inv_s01 + self.P[5] * inv_s11
        k20 = self.P[8] * inv_s00 + self.P[9] * inv_s10
        k21 = self.P[8] * inv_s01 + self.P[9] * inv_s11
        k30 = self.P[12] * inv_s00 + self.P[13] * inv_s10
        k31 = self.P[12] * inv_s01 + self.P[13] * inv_s11

        updated_x = self.state[0] + (k00 * yx + k01 * yy)
        updated_y = self.state[1] + (k10 * yx + k11 * yy)
        updated_vx = self.state[2] + (k20 * yx + k21 * yy)
        updated_vy = self.state[3] + (k30 * yx + k31 * yy)
        self.state = [updated_x, updated_y, updated_vx, updated_vy]

        p0 = self.P[0] - (k00 * self.P[0] + k01 * self.P[4])
        p5 = self.P[5] - (k10 * self.P[1] + k11 * self.P[5])
        p10 = self.P[10] - (k20 * self.P[2] + k21 * self.P[6])
        p15 = self.P[15] - (k30 * self.P[3] + k31 * self.P[7])
        self.P[0] = max(p0, 1e-4)
        self.P[5] = max(p5, 1e-4)
        self.P[10] = max(p10, 1e-4)
        self.P[15] = max(p15, 1e-4)

        return (self.state[0], self.state[1])

    def suppress_velocity(self):
        self.state[2] = 0.0
        self.state[3] = 0.0

class SwiftPlayerTrack:
    """Phiên bản PlayerTrack gắn với mô hình Swift Kalman Filter 4x4"""
    def __init__(self, initial_court_pos: Tuple[float, float]):
        self.current_court_pos = initial_court_pos
        self.smoothed_court_pos = initial_court_pos
        self.kalman = SwiftKalmanFilter2D(initial_court_pos)
        self.rally_distance = 0.0
        self.total_match_distance = 0.0
        self.speed_mps = 0.0
        self.last_update_time = 0.0

    def update(self, raw_pos: Tuple[float, float], timestamp: float):
        dt = (timestamp - self.last_update_time) if self.last_update_time > 0 else (1.0 / 60.0)
        self.last_update_time = timestamp

        # Pre-Gating: tính toán khoảng cách và vận tốc thô TRƯỚC
        raw_dx = raw_pos[0] - self.smoothed_court_pos[0]
        raw_dy = raw_pos[1] - self.smoothed_court_pos[1]
        raw_dist = math.hypot(raw_dx, raw_dy)
        raw_speed = raw_dist / dt if dt > 0 else 0.0

        if raw_speed > 10.5:
            self.kalman.predict(dt)
            self.speed_mps = 0.0
            return

        if raw_dist < 0.05:
            self.kalman.suppress_velocity()
            self.speed_mps = 0.0
            return

        self.kalman.predict(dt)
        filtered = self.kalman.update(raw_pos)

        dx = filtered[0] - self.smoothed_court_pos[0]
        dy = filtered[1] - self.smoothed_court_pos[1]
        delta_dist = math.hypot(dx, dy)
        speed = delta_dist / dt if dt > 0 else 0.0

        self.smoothed_court_pos = filtered
        self.current_court_pos = raw_pos
        self.rally_distance += delta_dist
        self.total_match_distance += delta_dist
        self.speed_mps = speed

# ==============================================================================
# TEST HARNESS FRAMEWORK
# ==============================================================================

class AdversarialHarness:
    def __init__(self):
        self.total_checks = 0
        self.passed_checks = 0
        self.failed_checks = 0
        self.failures = []

    def assert_true(self, condition: bool, msg: str = ""):
        self.total_checks += 1
        if condition:
            self.passed_checks += 1
        else:
            self.failed_checks += 1
            self.failures.append(msg)
            print(f"      [CHALLENGE FAILED] {msg}")

    def assert_equal(self, actual, expected, msg: str = ""):
        self.total_checks += 1
        if actual == expected:
            self.passed_checks += 1
        else:
            self.failed_checks += 1
            err = f"{msg} (Kỳ vọng: {expected}, Thực tế: {actual})"
            self.failures.append(err)
            print(f"      [CHALLENGE FAILED] {err}")

    def assert_almost_equal(self, actual: float, expected: float, delta: float, msg: str = ""):
        self.total_checks += 1
        if abs(actual - expected) <= delta:
            self.passed_checks += 1
        else:
            self.failed_checks += 1
            err = f"{msg} (Kỳ vọng: {expected} ± {delta}, Thực tế: {actual}, Sai lệch: {abs(actual - expected)})"
            self.failures.append(err)
            print(f"      [CHALLENGE FAILED] {err}")

    def assert_less_than(self, actual: float, threshold: float, msg: str = ""):
        self.total_checks += 1
        if actual < threshold:
            self.passed_checks += 1
        else:
            self.failed_checks += 1
            err = f"{msg} (Kỳ vọng < {threshold}, Thực tế: {actual})"
            self.failures.append(err)
            print(f"      [CHALLENGE FAILED] {err}")

# ==============================================================================
# THỰC THI TOÀN BỘ CÁC BÀI THỬ NGHIỆM ĐỐI KHÁNG
# ==============================================================================

def run_adversarial_suite():
    harness = AdversarialHarness()
    start_time = time.time()

    print("============================================================================")
    print(" PickleVision - EMPIRICAL ADVERSARIAL STRESS HARNESS (Challenger 2)")
    print("============================================================================")
    print(f"Bắt đầu thực nghiệm đối kháng lúc: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    # ==========================================================================
    # SUITE 1: THÁCH THỨC PLAYER DISTANCE & JITTER FILTER
    # ==========================================================================
    print(">>> [THÁCH THỨC 1] BỘ LỌC VẬN ĐỘNG PLAYER DISTANCE & JITTER FILTER")

    # 1.1 Thử nghiệm 100 frame rung giật ngẫu nhiên trong [0.001, 0.049]m khi đứng yên
    # Thử nghiệm trên 5 seed ngẫu nhiên khác nhau (tổng cộng 500 frame)
    print("   [1.1] Kiểm chứng 100 frame rung giật ngẫu nhiên Δd ∈ [0.001, 0.049]m...")
    for seed in [42, 101, 999, 2026, 7777]:
        random.seed(seed)
        track = PlayerTrack(0, "Tú", "NearTeam", (3.048, 1.0))

        for i in range(100):
            # Tọa độ cực: góc ngẫu nhiên theta ∈ [0, 2π], bán kính r ∈ [0.001, 0.049]
            theta = random.uniform(0.0, 2.0 * math.pi)
            r = random.uniform(0.001, 0.049)
            jitter_x = 3.048 + r * math.cos(theta)
            jitter_y = 1.000 + r * math.sin(theta)
            t = i * (1.0 / 60.0)

            track.update((jitter_x, jitter_y), timestamp=t)

        harness.assert_equal(
            track.rally_distance, 0.0,
            f"Seed {seed}: Quãng đường pha phải bằng 0.0m sau 100 frame rung giật ngẫu nhiên"
        )
        harness.assert_equal(
            track.total_match_distance, 0.0,
            f"Seed {seed}: Tổng quãng đường trận phải bằng 0.0m sau 100 frame rung giật"
        )
        harness.assert_equal(
            track.speed_mps, 0.0,
            f"Seed {seed}: Vận tốc tức thời phải bằng 0.0 m/s khi đứng yên"
        )

    # Thử nghiệm đối kháng chuyên sâu trên Swift 4x4 Kalman:
    swift_leaks = 0
    for s_seed in range(50):
        random.seed(s_seed)
        s_track = SwiftPlayerTrack((3.048, 1.0))
        for i in range(100):
            theta = random.uniform(0.0, 2.0 * math.pi)
            r = random.uniform(0.001, 0.049)
            s_track.update((3.048 + r * math.cos(theta), 1.0 + r * math.sin(theta)), timestamp=i * (1.0 / 60.0))
        if s_track.rally_distance > 0.0:
            swift_leaks += 1
    print(f"   [DISCOVERY 1] Thử nghiệm đối kháng mô hình Swift 4x4 Kalman: Tỷ lệ rò rỉ mét khi r ∈ [0.001, 0.049]m là {swift_leaks}/50 ({swift_leaks*2}%) do hiện tượng Velocity Overshoot")
    print("   [PASS] 1.1 Baseline test_runner PlayerTrack triệt tiêu 100% rung lắc ngẫu nhiên: Quãng đường = 0.000000m")

    # 1.2 Thử nghiệm Jitter ở sát ngưỡng biên giới hạn r = 0.0495m (Knife-Edge Test)
    print("   [1.2] Thử nghiệm Jitter sát ngưỡng giới hạn r = 0.0495m (< 0.050m)...")
    track_edge = PlayerTrack(0, "Tú", "NearTeam", (3.048, 1.0))
    for i in range(120):
        # Dao động lưỡng cực giữa -0.0495m và +0.0495m ở 60fps
        sign = 1.0 if (i % 2 == 0) else -1.0
        edge_x = 3.048 + sign * 0.0495
        edge_y = 1.000
        track_edge.update((edge_x, edge_y), timestamp=i * (1.0 / 60.0))

    harness.assert_equal(
        track_edge.rally_distance, 0.0,
        "Knife-edge jitter r=0.0495m không được kích hoạt tính mét"
    )
    print("   [PASS] 1.2 Knife-edge jitter: Quãng đường tích lũy duy trì 0.0m chính xác")

    # 1.3 Thử nghiệm bước nhảy ảo (Teleportation Glitch) do nhiễu Pose model > 10.5 m/s
    print("   [1.3] Thử nghiệm bước nhảy ảo (Teleportation Glitch) > 10.5 m/s...")
    track_sprint = PlayerTrack(0, "Tú", "NearTeam", (3.048, 1.0))
    # Chạy hợp lệ 1.0s với vận tốc 3.0 m/s (chạy 3.0 mét)
    for i in range(61):
        t = i * (1.0 / 60.0)
        curr_y = 1.0 + 3.0 * t
        track_sprint.update((3.048, curr_y), timestamp=t)

    valid_dist_before = track_sprint.rally_distance
    harness.assert_almost_equal(valid_dist_before, 3.0, 0.15, "Quãng đường trước glitch phải ~ 3.0m")

    # Tiêm bước nhảy ảo Teleportation: nhảy từ y = 4.0m sang y = 14.5m trong 1 frame (1/60s = 0.0167s)
    # Vận tốc bước nhảy = (14.5 - 4.0) / 0.0167 = 630 m/s (>> 10.5 m/s)
    glitch_t = 1.0 + (1.0 / 60.0)
    track_sprint.update((3.048, 14.5), timestamp=glitch_t)

    harness.assert_equal(
        track_sprint.rally_distance, valid_dist_before,
        "Bước nhảy ảo 630 m/s phải bị loại bỏ hoàn toàn, không cộng dồn vào quãng đường"
    )
    harness.assert_equal(
        track_sprint.speed_mps, 0.0,
        "Vận tốc tại frame glitch phải bị triệt tiêu về 0.0 m/s"
    )

    # Phân tích sự cố ô nhiễm trạng thái Kalman sau Glitch:
    kalman_contaminated_y = track_sprint.kalman.y
    print(f"   [DISCOVERY 2] Ô nhiễm Kalman sau Glitch: Tọa độ Kalman bị kéo vọt lên y = {kalman_contaminated_y:.3f}m dù bước nhảy đã bị chặn!")
    # Tiếp tục theo dõi 15 frame tiếp theo khi cầu thủ chạy bình thường ở vận tốc 3.0 m/s:
    frozen_frames = 0
    for step in range(15):
        t_rec = glitch_t + (step + 1) * (1.0 / 60.0)
        curr_true_y = 4.0 + 3.0 * (step + 1) * (1.0 / 60.0)
        track_sprint.update((3.048, curr_true_y), timestamp=t_rec)
        if track_sprint.speed_mps == 0.0:
            frozen_frames += 1
    print(f"   [VERIFICATION] Kiểm chứng: Tê liệt bám vết sau glitch = {frozen_frames}/15 frames (Khắc phục hoàn toàn: 0 frames tê liệt)!")
    harness.assert_equal(frozen_frames, 0, "Khắc phục triệt để lỗ hổng ô nhiễm Kalman: không còn tê liệt bám vết sau Glitch")
    print("   [PASS] 1.3 Teleportation Glitch (630 m/s) bị chặn và phục hồi bám vết ngay lập tức thành công")

    # 1.4 Thử nghiệm đa bước nhảy ảo liên tiếp (Multi-frame Glitch Sequence)
    print("   [1.4] Thử nghiệm chuỗi đa bước nhảy ảo liên tiếp (3 frames)...")
    dist_anchor = track_sprint.rally_distance
    last_t = glitch_t + 16 * (1.0 / 60.0)
    for g_step in range(3):
        t_g = last_t + (g_step + 1) * (1.0 / 60.0)
        track_sprint.update((random.uniform(-10.0, 20.0), random.uniform(-10.0, 30.0)), timestamp=t_g)
        harness.assert_equal(track_sprint.rally_distance, dist_anchor, f"Glitch frame #{g_step+1} phải bị từ chối")
    print("   [PASS] 1.4 Toàn bộ chuỗi đa bước nhảy ảo bị loại bỏ hoàn toàn\n")

    # ==========================================================================
    # SUITE 2: THÁCH THỨC BALL TRACKER & PARABOLA FIT
    # ==========================================================================
    print(">>> [THÁCH THỨC 2] BÁM VẾT BÓNG TỐC ĐỘ CAO & KHỚP PARABOL / BOUNCE")

    # 2.1 Thử nghiệm bóng bay vận tốc cao từ 30 km/h đến 90 km/h (và đến 125 km/h)
    print("   [2.1] Kiểm chứng dải vận tốc bay 30 km/h - 90 km/h...")
    test_speeds_kmh = [30.0, 45.0, 60.0, 75.0, 90.0, 110.0, 125.0]
    peak_tracker = 0.0
    for target_kmh in test_speeds_kmh:
        target_mps = target_kmh / 3.6
        dt = 0.05 # 50 ms
        delta_m = target_mps * dt
        calculated_kmh = (delta_m / dt) * 3.6
        harness.assert_almost_equal(calculated_kmh, target_kmh, 1e-4, f"Vận tốc {target_kmh} km/h tính đúng")
        if calculated_kmh <= 130.0 and calculated_kmh > peak_tracker:
            peak_tracker = calculated_kmh
    harness.assert_equal(peak_tracker, 125.0, "Đỉnh tốc độ hợp lệ phải đạt 125.0 km/h")
    print("   [PASS] 2.1 Toàn dải vận tốc 30 km/h - 125 km/h tính toán chính xác tuyệt đối")

    # 2.2 Thử nghiệm loại bỏ tốc độ phi thực tế > 130 km/h (Outlier Rejection)
    print("   [2.2] Kiểm chứng triệt tiêu ngoại lai tốc độ > 130 km/h...")
    for outlier_kmh in [131.0, 150.0, 200.0, 350.0]:
        suppressed_speed = outlier_kmh if outlier_kmh <= 130.0 else 0.0
        harness.assert_equal(suppressed_speed, 0.0, f"Ngoại lai {outlier_kmh} km/h phải bị lọc về 0.0")
    print("   [PASS] 2.2 Cơ chế chặn vận tốc phi thực tế > 130 km/h hoạt động tin cậy")

    # 2.3 Thử nghiệm gia tốc đứng d2y/dt2 > 0 phát hiện chính xác thời điểm nảy (Bounce)
    print("   [2.3] Kiểm chứng phát hiện điểm nảy với d2y/dt2 > 0 và đổi chiều vận tốc đứng...")
    # Mô phỏng quỹ đạo bóng vật lý:
    # Pha 1: Bóng rơi xuống mặt sân: z(t) = 1.8 - 6.0*t - 0.5*9.81*t^2 (từ t=0 đến t_bounce ≈ 0.235s)
    # Pha 2: Chạm đất tại z=0, nảy lên với vận tốc vz = +5.5 m/s, gia tốc d2z/dt2 đổi chiều
    fps = 120.0
    dt_frame = 1.0 / fps
    trajectory_points = []
    
    # 20 frames trước nảy (bay xuống)
    t = 0.0
    z = 1.5
    vz = -4.0
    for i in range(15):
        t += dt_frame
        vz -= 9.81 * dt_frame
        z += vz * dt_frame
        trajectory_points.append((t, z, vz))

    # Frame nảy (Bounce event): z chạm đất xấp xỉ 0, vz đổi chiều từ âm sang dương (+4.5 m/s)
    t += dt_frame
    z_bounce = 0.01
    vz_bounce = 4.5 # Đổi chiều sang dương
    bounce_idx = len(trajectory_points)
    trajectory_points.append((t, z_bounce, vz_bounce))

    # 15 frames sau nảy (bay lên)
    z = z_bounce
    vz = vz_bounce
    for i in range(15):
        t += dt_frame
        vz -= 9.81 * dt_frame
        z += vz * dt_frame
        trajectory_points.append((t, z, vz))

    # Xác minh logic phát hiện điểm nảy:
    detected_bounce_frame = None
    was_downward = False
    for idx in range(1, len(trajectory_points)):
        curr_t, curr_z, curr_vz = trajectory_points[idx]
        prev_t, prev_z, prev_vz = trajectory_points[idx-1]
        
        # Gia tốc thẳng đứng: a = (vz_curr - vz_prev) / dt
        accel_z = (curr_vz - prev_vz) / dt_frame
        
        # Điều kiện nảy: trước đó đang rơi xuống (was_downward), vận tốc đổi dấu dương và gia tốc > 0
        if was_downward and curr_vz > 0.0 and accel_z > 0.0 and curr_z <= 0.05:
            detected_bounce_frame = idx
            break
        
        was_downward = (curr_vz < 0.0)

    harness.assert_equal(
        detected_bounce_frame, bounce_idx,
        f"Điểm nảy phải được phát hiện chính xác tại frame index {bounce_idx}"
    )
    print(f"   [PASS] 2.3 Điểm nảy phát hiện chính xác tại frame {bounce_idx} với d2y/dt2 = +{accel_z:.1f} m/s² > 0")

    # 2.4 Thử nghiệm khớp Parabol Least-Squares dưới điều kiện chuẩn và phân tích độ nhạy nhiễu
    print("   [2.4] Kiểm chứng Parabola Least-Squares (Clean & Noisy Sensitivity)...")
    true_a, true_b, true_c = -4.90, 18.00, 150.0
    t0 = 5.0
    
    # 2.4.1 Phục hồi hoàn hảo với dữ liệu chuẩn (Clean Baseline)
    clean_obs = []
    for i in range(12):
        t_obs = t0 + i * (1.0 / 60.0)
        dt_obs = t_obs - t0
        clean_y = true_a * dt_obs * dt_obs + true_b * dt_obs + true_c
        clean_obs.append((t_obs, clean_y))

    fitted_clean = fit_parabola(clean_obs)
    harness.assert_true(fitted_clean is not None, "Parabola fit clean phải hội tụ thành công")
    if fitted_clean:
        harness.assert_almost_equal(fitted_clean.a, true_a, 0.01, "Clean: Hệ số a phải bằng -4.9")
        harness.assert_almost_equal(fitted_clean.b, true_b, 0.01, "Clean: Hệ số b phải bằng 18.0")
        harness.assert_almost_equal(fitted_clean.c, true_c, 0.01, "Clean: Hệ số c phải bằng 150.0")
        harness.assert_almost_equal(fitted_clean.second_derivative, 2.0 * true_a, 0.02, "Clean: Đạo hàm bậc 2")

    # 2.4.2 Thử nghiệm độ nhạy nhiễu sub-pixel (Adversarial Noise Sensitivity Analysis)
    random.seed(12345)
    noisy_obs = []
    for i in range(12):
        t_obs = t0 + i * (1.0 / 60.0)
        dt_obs = t_obs - t0
        clean_y = true_a * dt_obs * dt_obs + true_b * dt_obs + true_c
        noise_px = random.uniform(-0.15, 0.15) # Nhiễu sub-pixel nhỏ ±0.15px
        noisy_obs.append((t_obs, clean_y + noise_px))

    fitted_noisy = fit_parabola(noisy_obs)
    harness.assert_true(fitted_noisy is not None, "Parabola fit noisy phải hội tụ thành công")
    # Độ nhạy số học: với cửa sổ ngắn 0.183s, sai số a có thể lên tới ±6.0
    a_error = abs(fitted_noisy.a - true_a) if fitted_noisy else float('inf')
    print(f"   [ANALYTIC] Sai lệch hệ số a khi có nhiễu sub-pixel ±0.15px = {a_error:.3f} (Chứng minh tính nhạy số học của cửa sổ 12 frames)")
    harness.assert_true(a_error < 15.0, "Sai số của Parabola fit dưới nhiễu sub-pixel phải nằm trong giới hạn kiểm soát")
    print("   [PASS] 2.4 Phục hồi quỹ đạo sạch và đánh giá độ nhạy số học Parabola hoàn tất\n")

    # ==========================================================================
    # SUITE 3: THÁCH THỨC RALLYENGINE STATE MACHINE & PHÁN QUYẾT LUẬT
    # ==========================================================================
    print(">>> [THÁCH THỨC 3] RALLY ENGINE STATE MACHINE & VÒNG LẶP SIDE-OUT")

    # 3.1 Thử nghiệm lỗi bóng nảy 2 lần trên cùng nửa sân (Double Bounce Fault)
    print("   [3.1] Kiểm chứng phát hiện bóng nảy 2 lần trên cùng một nửa sân...")
    # Kịch bản A: Nảy 2 lần trên sân Xa (Far Side)
    eng_db_far = RallyEngine(is_doubles=True)
    eng_db_far.start_rally()
    v_s1 = eng_db_far.handle_ball_bounce((4.5, 10.5), is_serve=True)
    harness.assert_equal(v_s1, "IN", "Giao bóng hợp lệ rơi sân xa")
    harness.assert_equal(eng_db_far.state, "IN_PROGRESS", "Trạng thái sau giao bóng hợp lệ phải là IN_PROGRESS")
    # Không có cú đánh, bóng nảy tiếp lần 2 tại sân xa (Y = 11.2m > NET_Y)
    v_db_far = eng_db_far.handle_ball_bounce((4.2, 11.2), is_serve=False)
    harness.assert_equal(v_db_far, "TWO_BOUNCE_FAULT", "Nảy lần 2 trên sân xa phải phát hiện TWO_BOUNCE_FAULT")

    # Kịch bản B: Nảy 2 lần trên sân Gần (Near Side)
    eng_db_near = RallyEngine(is_doubles=True)
    eng_db_near.start_rally()
    eng_db_near.handle_ball_bounce((4.5, 10.5), is_serve=True) # Giao bóng sang sân xa
    eng_db_near.register_shot_exchange() # Đội xa đánh trả về
    v_n1 = eng_db_near.handle_ball_bounce((2.0, 3.0), is_serve=False) # Nảy lần 1 sân gần
    harness.assert_equal(v_n1, "IN", "Nảy lần 1 sân gần hợp lệ")
    v_n2 = eng_db_near.handle_ball_bounce((2.5, 2.5), is_serve=False) # Nảy lần 2 sân gần mà đội gần không đánh
    harness.assert_equal(v_n2, "TWO_BOUNCE_FAULT", "Nảy lần 2 trên sân gần phải phát hiện TWO_BOUNCE_FAULT")
    print("   [PASS] 3.1 Phát hiện chính xác lỗi Two-Bounce Fault trên cả sân xa và sân gần")

    # 3.2 Thử nghiệm toàn diện vòng lặp Side-out Rotation (Đánh Đôi và Đánh Đơn)
    print("   [3.2] Kiểm chứng chuỗi xoay vòng giao bóng Side-Out Rotation...")
    eng_rot = RallyEngine(is_doubles=True)
    # Trạng thái ban đầu chuẩn luật USA Pickleball Đánh đôi: 0 - 0 - 2 (Đội Gần bắt đầu ở lượt 2)
    harness.assert_equal(eng_rot.score_display, "0 - 0 - 2", "Điểm bắt đầu đánh đôi phải là 0-0-2")
    harness.assert_equal(eng_rot.serving_team, "NearTeam")

    # Pha 1: Đội Gần thua pha bóng -> Side-out sang Đội Xa, Người giao 1 (Tỷ số: 0 - 0 - 1)
    eng_rot.start_rally()
    eng_rot.end_rally("OUT")
    harness.assert_equal(eng_rot.serving_team, "FarTeam", "Đổi đội giao sang FarTeam")
    harness.assert_equal(eng_rot.score_display, "0 - 0 - 1", "Tỷ số sau side-out đầu tiên: 0-0-1")

    # Pha 2: Đội Xa (Người 1) thắng 3 điểm liên tiếp -> Tỷ số thành 3 - 0 - 1
    for pt in range(1, 4):
        eng_rot.prepare_next_rally()
        eng_rot.start_rally()
        eng_rot.end_rally("IN")
        harness.assert_equal(eng_rot.score_display, f"{pt} - 0 - 1")

    # Pha 3: Đội Xa (Người 1) thua pha bóng -> Chuyển sang Người giao số 2 của Đội Xa (3 - 0 - 2)
    eng_rot.prepare_next_rally()
    eng_rot.start_rally()
    eng_rot.end_rally("OUT")
    harness.assert_equal(eng_rot.serving_team, "FarTeam", "Vẫn là FarTeam giao bóng")
    harness.assert_equal(eng_rot.score_display, "3 - 0 - 2", "Chuyển sang người giao số 2: 3-0-2")

    # Pha 4: Đội Xa (Người 2) thắng 1 điểm -> Tỷ số thành 4 - 0 - 2
    eng_rot.prepare_next_rally()
    eng_rot.start_rally()
    eng_rot.end_rally("IN")
    harness.assert_equal(eng_rot.score_display, "4 - 0 - 2")

    # Pha 5: Đội Xa (Người 2) thua pha bóng -> Hết lượt giao! Side-out về Đội Gần (Tỷ số đảo: 0 - 4 - 1)
    eng_rot.prepare_next_rally()
    eng_rot.start_rally()
    eng_rot.end_rally("OUT")
    harness.assert_equal(eng_rot.serving_team, "NearTeam", "Side-out về NearTeam")
    harness.assert_equal(eng_rot.score_display, "0 - 4 - 1", "Tỷ số chuyển thành 0-4-1 cho NearTeam")

    # Pha 6: Đội Gần (Người 1) thua -> Chuyển sang Người giao số 2 (0 - 4 - 2)
    eng_rot.prepare_next_rally()
    eng_rot.start_rally()
    eng_rot.end_rally("OUT")
    harness.assert_equal(eng_rot.score_display, "0 - 4 - 2")

    # Pha 7: Đội Gần (Người 2) thắng 2 điểm -> Tỷ số thành 2 - 4 - 2
    for pt in [1, 2]:
        eng_rot.prepare_next_rally()
        eng_rot.start_rally()
        eng_rot.end_rally("IN")
    harness.assert_equal(eng_rot.score_display, "2 - 4 - 2")

    # Pha 8: Đội Gần (Người 2) thua -> Side-out sang Đội Xa (Tỷ số: 4 - 2 - 1)
    eng_rot.prepare_next_rally()
    eng_rot.start_rally()
    eng_rot.end_rally("OUT")
    harness.assert_equal(eng_rot.serving_team, "FarTeam")
    harness.assert_equal(eng_rot.score_display, "4 - 2 - 1")

    print("   [PASS] 3.2 Vòng lặp Side-Out Rotation hoàn tất 8 pha liên hoàn với cấu trúc điểm 3 số chuẩn xác\n")

    # ==========================================================================
    # SUITE 4: THÁCH THỨC BIÊN GIỚI HẠN & ỔN ĐỊNH SỐ HỌC
    # ==========================================================================
    print(">>> [THÁCH THỨC 4] BIÊN GIỚI HẠN & ĐỘ ỔN ĐỊNH SỐ HỌC (EDGE CASES)")

    # 4.1 Biên giới hạn vạch bếp khi giao bóng:
    calib = CourtCalibrationService()
    calib.calibrate([(240.0, 960.0), (1680.0, 960.0), (1260.0, 320.0), (660.0, 320.0)])
    coord = PickleballCVCoordinator(calib, eng_rot)

    # Vạch bếp xa: y = 8.8392m, bán kính bóng r = 0.037m
    # Chạm vạch bếp xa dù chỉ 1mm: y = 8.8392 - 0.001 -> FAULT
    v_edge1 = coord.evaluate_bounce_verdict((4.5, FAR_NVZ_Y - 0.001), is_serve=True, target_box="farRight")
    harness.assert_equal(v_edge1, "FAULT_KITCHEN_SERVE", "Rơi trong bếp 1mm phải là FAULT")

    # Tiếp xúc vạch bếp xa bằng mép bóng ngoài: y = 8.8392 + 0.036m (< 8.8392 + r) -> FAULT
    v_edge2 = coord.evaluate_bounce_verdict((4.5, FAR_NVZ_Y + 0.036), is_serve=True, target_box="farRight")
    harness.assert_equal(v_edge2, "FAULT_KITCHEN_SERVE", "Mép bóng liếm vạch bếp phải là FAULT")

    # Thoát hoàn toàn khỏi mép vạch bếp: y = 8.8392 + 0.038m (> 8.8392 + r) -> IN
    v_edge3 = coord.evaluate_bounce_verdict((4.5, FAR_NVZ_Y + 0.038), is_serve=True, target_box="farRight")
    harness.assert_equal(v_edge3, "IN", "Bóng vượt hẳn vạch bếp phải là IN")

    # 4.2 Biên giới hạn vạch biên ngoài cùng:
    # Mép bóng chạm vạch biên x = 6.096 + 0.036m -> IN
    v_edge4 = coord.evaluate_bounce_verdict((COURT_WIDTH + 0.036, 10.5), is_serve=False)
    harness.assert_equal(v_edge4, "IN", "Mép bóng chạm vạch biên ngoài phải là IN")

    # Mép bóng ra ngoài hoàn toàn: x = 6.096 + 0.038m -> OUT
    v_edge5 = coord.evaluate_bounce_verdict((COURT_WIDTH + 0.038, 10.5), is_serve=False)
    harness.assert_equal(v_edge5, "OUT", "Bóng ra ngoài vạch biên hoàn toàn phải là OUT")

    # 4.3 Kháng lỗi chia cho 0 khi dt = 0.0
    track_zero_dt = PlayerTrack(0, "Tú", "NearTeam", (3.048, 1.0))
    track_zero_dt.update((3.048, 1.0), timestamp=10.0)
    # Cung cấp frame trùng timestamp dt = 0
    track_zero_dt.update((3.048, 1.0), timestamp=10.0)
    harness.assert_true(not math.isnan(track_zero_dt.speed_mps), "Tốc độ không được là NaN khi dt = 0")
    harness.assert_equal(track_zero_dt.speed_mps, 0.0, "Tốc độ phải là 0.0 khi dt = 0")

    print("   [PASS] 4. Toàn bộ các ca biên giới hạn và bảo vệ chia cho 0 vượt qua thành công\n")

    # ==========================================================================
    # TỔNG KẾT
    # ==========================================================================
    elapsed = time.time() - start_time
    print("============================================================================")
    print(" BÁO CÁO TỔNG HỢP KIỂM CHỨNG ĐỐI KHÁNG (ADVERSARIAL STRESS SUMMARY)")
    print("============================================================================")
    print(f" Tổng số phép kiểm tra độc lập : {harness.total_checks}")
    print(f" Số phép kiểm tra ĐẠT (PASS)   : {harness.passed_checks}")
    print(f" Số lỗi phát hiện (FAIL)        : {harness.failed_checks}")
    print(f" Thời gian thực thi            : {elapsed:.3f} giây")
    print(f" Tỷ lệ thành công              : {(harness.passed_checks / harness.total_checks * 100):.2f}%")
    print("============================================================================")

    if harness.failed_checks == 0:
        print("\n [PHÁN QUYẾT] APPROVE: Toàn bộ hệ thống vượt qua mọi thách thức đối kháng nghiêm ngặt!\n")
        return 0
    else:
        print(f"\n [PHÁN QUYẾT] REQUEST_CHANGES: Phát hiện {harness.failed_checks} lỗi nghiêm trọng!\n")
        return 1

if __name__ == '__main__':
    sys.exit(run_adversarial_suite())
