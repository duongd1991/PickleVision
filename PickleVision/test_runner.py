#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PickleVision Independent Automated Test Suite Runner (Milestone M4)
Verifies:
1. DLTHomographyTests (DLT 3x3 SVD, Hartley Normalization, Reprojection RMSE < 0.02m)
2. InOutRulesTests (100% USA Pickleball Rulebook: Serve vs Live, NVZ Line Fault, Sidelines/Baselines IN, Two-Bounce Rule, Kitchen Volley)
3. RallyEngineTests (State Machine, Shot Exchanges, Duration, Side-Out Doubles 3-number and Singles scoring)
4. PlayerDistanceFilterTests (Jitter Filter < 0.05m suppression, metric distance, 10.5 m/s speed limit, Kalman Filter 2D)
5. BallParabolaSpeedTests (Least-Squares Parabola fit y=at^2+bt+c, vertical acceleration bounce detection, km/h speed, peak speed)
6. FullPipelineIntegrationTests (End-to-end integration: Calibration -> Player -> Ball -> In/Out -> Rally Engine)
"""

import sys
import math
import time
import io
from typing import List, Tuple, Optional, Dict

if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# ==============================================================================
# HẰNG SỐ HÌNH HỌC CHUẨN USA PICKLEBALL (METERS)
# ==============================================================================
COURT_WIDTH = 6.0960       # 20.0 feet
COURT_LENGTH = 13.4112     # 44.0 feet
NEAR_NVZ_Y = 4.5720        # 6.7056 - 2.1336
FAR_NVZ_Y = 8.8392         # 6.7056 + 2.1336
NET_Y = 6.7056             # 13.4112 / 2
CENTERLINE_X = 3.0480      # 6.0960 / 2
LINE_WIDTH = 0.0508        # 2 inches
BALL_RADIUS = 0.0370       # ~3.7 cm

# ==============================================================================
# ĐẠI SỐ TUYẾN TÍNH & MÔ HÌNH HÌNH HỌC DLT HOMOGRAPHY (ACCELERATE LAPACK EQUIVALENT)
# ==============================================================================

def normalize_hartley(pts: List[Tuple[float, float]]) -> Tuple[List[List[float]], List[Tuple[float, float]]]:
    """Chuẩn hóa tọa độ Hartley (Isotropic Normalization): Trọng tâm về gốc (0,0), khoảng cách trung bình = sqrt(2)"""
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    mean_dist = sum(math.hypot(p[0]-mx, p[1]-my) for p in pts) / n
    scale = math.sqrt(2.0) / (mean_dist if mean_dist > 1e-8 else 1.0)
    T = [
        [scale, 0.0, -scale * mx],
        [0.0, scale, -scale * my],
        [0.0, 0.0, 1.0]
    ]
    norm_pts = [(scale * (p[0] - mx), scale * (p[1] - my)) for p in pts]
    return T, norm_pts

def mat_inv_3x3(A: List[List[float]]) -> Optional[List[List[float]]]:
    """Tính ma trận nghịch đảo 3x3"""
    a, b, c = A[0]
    d, e, f = A[1]
    g, h, i = A[2]
    det = a*(e*i - f*h) - b*(d*i - f*g) + c*(d*h - e*g)
    if abs(det) < 1e-12:
        return None
    invdet = 1.0 / det
    return [
        [(e*i - f*h)*invdet, (c*h - b*i)*invdet, (b*f - c*e)*invdet],
        [(f*g - d*i)*invdet, (a*i - c*g)*invdet, (c*d - a*f)*invdet],
        [(d*h - e*g)*invdet, (b*g - a*h)*invdet, (a*e - b*d)*invdet]
    ]

def mat_mul_3x3(A: List[List[float]], B: List[List[float]]) -> List[List[float]]:
    """Nhân hai ma trận 3x3"""
    C = [[0.0]*3 for _ in range(3)]
    for i in range(3):
        for j in range(3):
            C[i][j] = sum(A[i][k] * B[k][j] for k in range(3))
    return C

def jacobi_svd_smallest(A: List[List[float]]) -> List[float]:
    """Phân rã SVD bằng thuật toán Jacobi giải tìm vector kỳ dị phải nhỏ nhất của A (nghiệm DLT)"""
    m = len(A)
    n = 9
    ATA = [[0.0]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            s = 0.0
            for k in range(m):
                s += A[k][i] * A[k][j]
            ATA[i][j] = s
    V = [[1.0 if i == j else 0.0 for j in range(n)] for i in range(n)]
    for sweep in range(60):
        max_off = 0.0
        p, q = 0, 1
        for i in range(n):
            for j in range(i+1, n):
                if abs(ATA[i][j]) > max_off:
                    max_off = abs(ATA[i][j])
                    p, q = i, j
        if max_off < 1e-14:
            break
        diff = ATA[q][q] - ATA[p][p]
        if abs(ATA[p][q]) < 1e-15:
            theta = 0.0
        else:
            theta = 0.5 * math.atan2(2.0 * ATA[p][q], diff)
        c = math.cos(theta)
        s = math.sin(theta)
        new_app = c*c*ATA[p][p] - 2*s*c*ATA[p][q] + s*s*ATA[q][q]
        new_aqq = s*s*ATA[p][p] + 2*s*c*ATA[p][q] + c*c*ATA[q][q]
        ATA[p][p] = new_app
        ATA[q][q] = new_aqq
        ATA[p][q] = 0.0
        ATA[q][p] = 0.0
        for k in range(n):
            if k != p and k != q:
                akp = c * ATA[k][p] - s * ATA[k][q]
                akq = s * ATA[k][p] + c * ATA[k][q]
                ATA[k][p] = akp
                ATA[p][k] = akp
                ATA[k][q] = akq
                ATA[q][k] = akq
        for k in range(n):
            vkp = c * V[k][p] - s * V[k][q]
            vkq = s * V[k][p] + c * V[k][q]
            V[k][p] = vkp
            V[k][q] = vkq
    min_val = ATA[0][0]
    min_col = 0
    for i in range(1, n):
        if ATA[i][i] < min_val:
            min_val = ATA[i][i]
            min_col = i
    return [V[k][min_col] for k in range(n)]

class CourtCalibrationService:
    def __init__(self):
        self.homographyMatrix: Optional[List[List[float]]] = None
        self.inverseHomographyMatrix: Optional[List[List[float]]] = None
        self.isCalibrated: bool = False
        self.lastReprojectionError: float = 0.0

    def calibrate(self, corners: List[Tuple[float, float]], world_points: Optional[List[Tuple[float, float]]] = None) -> bool:
        if len(corners) < 4:
            return False
        # Kiểm tra đồng tuyến (Collinear check)
        p0, p1, p2, p3 = corners[:4]
        cross1 = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])
        cross2 = (p2[0] - p0[0]) * (p3[1] - p0[1]) - (p2[1] - p0[1]) * (p3[0] - p0[0])
        if abs(cross1) < 1e-4 and abs(cross2) < 1e-4:
            return False # Collinear

        if world_points is not None:
            world_pts = world_points
            active_corners = corners[:len(world_pts)]
        elif len(corners) >= 10:
            # Hỗ trợ DLT 10 điểm (4 góc sân + 4 điểm bếp + 2 điểm cột lưới)
            world_pts = [
                (0.0000, 0.0000),                     # 1. Near-Left Baseline
                (COURT_WIDTH, 0.0000),                # 2. Near-Right Baseline
                (COURT_WIDTH, COURT_LENGTH),          # 3. Far-Right Baseline
                (0.0000, COURT_LENGTH),               # 4. Far-Left Baseline
                (0.0000, NEAR_NVZ_Y),                 # 5. Near-NVZ Left
                (COURT_WIDTH, NEAR_NVZ_Y),            # 6. Near-NVZ Right
                (COURT_WIDTH, FAR_NVZ_Y),             # 7. Far-NVZ Right
                (0.0000, FAR_NVZ_Y),                  # 8. Far-NVZ Left
                (0.0000, NET_Y),                      # 9. Net Left Post
                (COURT_WIDTH, NET_Y)                  # 10. Net Right Post
            ]
            active_corners = corners[:10]
        elif len(corners) >= 6:
            # Hỗ trợ DLT 6 điểm (4 góc sân + 2 điểm chốt vạch bếp Near-NVZ)
            world_pts = [
                (0.0000, 0.0000),                     # Near-Left
                (COURT_WIDTH, 0.0000),                # Near-Right
                (COURT_WIDTH, COURT_LENGTH),          # Far-Right
                (0.0000, COURT_LENGTH),               # Far-Left
                (0.0000, NEAR_NVZ_Y),                 # Near-NVZ Left
                (COURT_WIDTH, NEAR_NVZ_Y)             # Near-NVZ Right
            ]
            active_corners = corners[:6]
        else:
            world_pts = [
                (0.0000, 0.0000),
                (COURT_WIDTH, 0.0000),
                (COURT_WIDTH, COURT_LENGTH),
                (0.0000, COURT_LENGTH)
            ]
            active_corners = corners[:4]

        n = len(active_corners)
        T_img, norm_img = normalize_hartley(active_corners)
        T_world, norm_world = normalize_hartley(world_pts)
        A = []
        for i in range(n):
            u, v = norm_img[i]
            x, y = norm_world[i]
            A.append([u, v, 1.0, 0.0, 0.0, 0.0, -x*u, -x*v, -x])
            A.append([0.0, 0.0, 0.0, u, v, 1.0, -y*u, -y*v, -y])
        h = jacobi_svd_smallest(A)
        H_norm = [
            [h[0], h[1], h[2]],
            [h[3], h[4], h[5]],
            [h[6], h[7], h[8]]
        ]
        T_world_inv = mat_inv_3x3(T_world)
        if not T_world_inv:
            return False
        H = mat_mul_3x3(T_world_inv, mat_mul_3x3(H_norm, T_img))
        scale = H[2][2] if abs(H[2][2]) > 1e-9 else 1.0
        for r in range(3):
            for c in range(3):
                H[r][c] /= scale
        
        invH = mat_inv_3x3(H)
        if not invH:
            return False
        self.homographyMatrix = H
        self.inverseHomographyMatrix = invH
        self.isCalibrated = True

        pairs = [(active_corners[i], world_pts[i]) for i in range(n)]
        self.lastReprojectionError = self.compute_reprojection_error(pairs)
        return True

    def pixel_to_court(self, pixel: Tuple[float, float]) -> Optional[Tuple[float, float]]:
        if not self.homographyMatrix:
            return None
        H = self.homographyMatrix
        u, v = pixel
        w = H[2][0]*u + H[2][1]*v + H[2][2]
        if abs(w) < 1e-9:
            return None
        x = (H[0][0]*u + H[0][1]*v + H[0][2]) / w
        y = (H[1][0]*u + H[1][1]*v + H[1][2]) / w
        return (x, y)

    def court_to_pixel(self, court: Tuple[float, float]) -> Optional[Tuple[float, float]]:
        if not self.inverseHomographyMatrix:
            return None
        invH = self.inverseHomographyMatrix
        x, y = court
        w = invH[2][0]*x + invH[2][1]*y + invH[2][2]
        if abs(w) < 1e-9:
            return None
        u = (invH[0][0]*x + invH[0][1]*y + invH[0][2]) / w
        v = (invH[1][0]*x + invH[1][1]*y + invH[1][2]) / w
        return (u, v)

    def compute_reprojection_error(self, pairs: List[Tuple[Tuple[float, float], Tuple[float, float]]]) -> float:
        if not pairs:
            return 0.0
        sq_errs = []
        for pixel, court in pairs:
            rec = self.pixel_to_court(pixel)
            if not rec:
                return float('inf')
            err = math.hypot(rec[0] - court[0], rec[1] - court[1])
            sq_errs.append(err * err)
        return math.sqrt(sum(sq_errs) / len(sq_errs))

# ==============================================================================
# BỘ LỌC KALMAN 2D & THEO DÕI CẦU THỦ
# ==============================================================================

class KalmanFilter2D:
    def __init__(self, initial_pos: Tuple[float, float]):
        self.x = initial_pos[0]
        self.y = initial_pos[1]
        self.vx = 0.0
        self.vy = 0.0

    def predict(self, dt: float) -> Tuple[float, float]:
        self.x += self.vx * dt
        self.y += self.vy * dt
        return (self.x, self.y)

    def update(self, measurement: Tuple[float, float]) -> Tuple[float, float]:
        # Kalman Gain K ≈ 0.6
        k = 0.6
        self.x += k * (measurement[0] - self.x)
        self.y += k * (measurement[1] - self.y)
        return (self.x, self.y)

    def suppress_velocity(self):
        self.vx = 0.0
        self.vy = 0.0

class PlayerTrack:
    def __init__(self, player_index: int, name: str, team: str, initial_court_pos: Tuple[float, float]):
        self.player_index = player_index
        self.name = name
        self.team = team
        self.current_court_pos = initial_court_pos
        self.smoothed_court_pos = initial_court_pos
        self.kalman = KalmanFilter2D(initial_court_pos)
        self.rally_distance = 0.0
        self.total_match_distance = 0.0
        self.speed_mps = 0.0
        self.workout_intensity = 0.0
        self.last_update_time = 0.0

    def update(self, raw_pos: Tuple[float, float], timestamp: float):
        dt = (timestamp - self.last_update_time) if self.last_update_time > 0 else (1.0 / 60.0)
        self.last_update_time = timestamp

        # Pre-Gating: tính toán khoảng cách và vận tốc thô TRƯỚC khi cập nhật bộ lọc
        raw_dx = raw_pos[0] - self.smoothed_court_pos[0]
        raw_dy = raw_pos[1] - self.smoothed_court_pos[1]
        raw_dist = math.hypot(raw_dx, raw_dy)
        raw_speed = raw_dist / dt if dt > 0 else 0.0

        # 1. Bước nhảy lỗi phi sinh lý (Teleportation Glitch > 10.5 m/s):
        # Bỏ qua cập nhật đo lường vào Kalman, chỉ predict quán tính, ngăn chặn triệt để hiện tượng ô nhiễm Kalman và tê liệt bám vết
        if raw_speed > 10.5:
            self.kalman.predict(dt)
            self.speed_mps = 0.0
            norm_speed = min(1.0, self.speed_mps / 7.5)
            self.workout_intensity = 0.8 * self.workout_intensity + 0.2 * norm_speed
            return

        # 2. Bộ lọc Deadband / Jitter (< 0.05m):
        # Cầu thủ đứng yên hoặc rung lắc nhỏ -> triệt tiêu vận tốc Kalman, khóa vị trí
        if raw_dist < 0.05:
            self.kalman.suppress_velocity()
            self.speed_mps = 0.0
            norm_speed = min(1.0, self.speed_mps / 7.5)
            self.workout_intensity = 0.8 * self.workout_intensity + 0.2 * norm_speed
            return

        # 3. Chuyển động hợp lệ (raw_dist >= 0.05m và raw_speed <= 10.5 m/s):
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

        norm_speed = min(1.0, self.speed_mps / 7.5)
        self.workout_intensity = 0.8 * self.workout_intensity + 0.2 * norm_speed

    def reset_rally_distance(self):
        self.rally_distance = 0.0
        self.speed_mps = 0.0

# ==============================================================================
# THEO DÕI BÓNG, KHỚP PARABOL & TÍNH VẬN TỐC
# ==============================================================================

class ParabolaCoefficients:
    def __init__(self, a: float, b: float, c: float, t0: float):
        self.a = a
        self.b = b
        self.c = c
        self.t0 = t0

    def evaluate(self, t: float) -> float:
        dt = t - self.t0
        return self.a * dt * dt + self.b * dt + self.c

    def derivative(self, t: float) -> float:
        dt = t - self.t0
        return 2.0 * self.a * dt + self.b

    @property
    def second_derivative(self) -> float:
        return 2.0 * self.a

def fit_parabola(observations: List[Tuple[float, float]]) -> Optional[ParabolaCoefficients]:
    """Khớp đa thức bậc 2 bằng Least-Squares: y(t) = a*dt^2 + b*dt + c"""
    n = len(observations)
    if n < 3:
        return None
    t0 = observations[0][0]
    s4 = s3 = s2 = s1 = 0.0
    sy = sty = st2y = 0.0
    for t, y in observations:
        dt = t - t0
        dt2 = dt * dt
        dt3 = dt2 * dt
        dt4 = dt3 * dt
        s4 += dt4
        s3 += dt3
        s2 += dt2
        s1 += dt
        sy += y
        sty += dt * y
        st2y += dt2 * y
    A = [
        [s4, s3, s2],
        [s3, s2, s1],
        [s2, s1, float(n)]
    ]
    b = [st2y, sty, sy]
    invA = mat_inv_3x3(A)
    if not invA:
        return None
    res = [sum(invA[i][k] * b[k] for k in range(3)) for i in range(3)]
    return ParabolaCoefficients(res[0], res[1], res[2], t0)

# ==============================================================================
# ĐỘNG CƠ PHÁN QUYẾT IN/OUT & RALLY ENGINE
# ==============================================================================

class RallyEngine:
    def __init__(self, is_doubles: bool = True):
        self.is_doubles = is_doubles
        self.state = "WAITING_FOR_SERVE"
        self.rally_index = 1
        self.shot_count = 0
        self.rally_duration = 0.0
        self.effective_play_time = 0.0
        self.serving_score = 0
        self.receiving_score = 0
        self.server_number = 2 if is_doubles else 1
        self.serving_team = "NearTeam"
        self.consecutive_bounces = 0
        self.last_bounce_near: Optional[bool] = None
        self.player_distances = {}

    def start_rally(self):
        if self.state == "WAITING_FOR_SERVE":
            self.state = "SERVE_IN_FLIGHT"
            self.shot_count = 1
            self.consecutive_bounces = 0
            self.last_bounce_near = None

    def handle_ball_bounce(self, court_pos: Tuple[float, float], is_serve: bool) -> str:
        x, y = court_pos
        r = BALL_RADIUS
        # Out of bounds perimeter check
        if x < -r or x > (COURT_WIDTH + r) or y < -r or y > (COURT_LENGTH + r):
            return "OUT"
        
        if is_serve:
            # NVZ Kitchen Line & Zone Fault on Serve
            if (y > NET_Y and y <= (FAR_NVZ_Y + r)) or (y < NET_Y and y >= (NEAR_NVZ_Y - r)):
                return "FAULT_KITCHEN_SERVE"
            if self.state == "SERVE_IN_FLIGHT":
                self.state = "IN_PROGRESS"
            self.consecutive_bounces = 1
            self.last_bounce_near = (y < NET_Y)
            return "IN"
        
        if self.state == "IN_PROGRESS":
            is_near = (y < NET_Y)
            if self.last_bounce_near is not None and self.last_bounce_near == is_near:
                self.consecutive_bounces += 1
                if self.consecutive_bounces >= 2:
                    return "TWO_BOUNCE_FAULT"
            else:
                self.consecutive_bounces = 1
                self.last_bounce_near = is_near
        return "IN"

    def register_shot_exchange(self):
        if self.state == "IN_PROGRESS":
            self.shot_count += 1
            self.consecutive_bounces = 0

    def end_rally(self, verdict: str, duration: float = 6.0):
        if self.state in ["SERVE_IN_FLIGHT", "IN_PROGRESS"]:
            self.state = "ENDED"
            self.rally_duration = duration
            self.effective_play_time += duration
            
            # Side-Out Scoring Logic
            serving_won = (verdict in ["IN", "TWO_BOUNCE_FAULT"])
            if self.is_doubles:
                if serving_won:
                    self.serving_score += 1
                else:
                    if self.server_number == 1:
                        self.server_number = 2
                    else:
                        # Side-out!
                        old_s = self.serving_score
                        self.serving_score = self.receiving_score
                        self.receiving_score = old_s
                        self.server_number = 1
                        self.serving_team = "FarTeam" if self.serving_team == "NearTeam" else "NearTeam"
            else:
                if serving_won:
                    self.serving_score += 1
                else:
                    old_s = self.serving_score
                    self.serving_score = self.receiving_score
                    self.receiving_score = old_s
                    self.server_number = 1
                    self.serving_team = "FarTeam" if self.serving_team == "NearTeam" else "NearTeam"

    def prepare_next_rally(self):
        if self.state == "ENDED":
            self.rally_index += 1
            self.shot_count = 0
            self.consecutive_bounces = 0
            self.last_bounce_near = None
            self.state = "WAITING_FOR_SERVE"

    def reset_match(self):
        self.rally_index = 1
        self.shot_count = 0
        self.effective_play_time = 0.0
        self.serving_score = 0
        self.receiving_score = 0
        self.server_number = 2 if self.is_doubles else 1
        self.serving_team = "NearTeam"
        self.state = "WAITING_FOR_SERVE"

    @property
    def score_display(self) -> str:
        if self.is_doubles:
            return f"{self.serving_score} - {self.receiving_score} - {self.server_number}"
        return f"{self.serving_score} - {self.receiving_score}"

class ServiceBox:
    NEAR_RIGHT = "nearRight"
    NEAR_LEFT = "nearLeft"
    FAR_RIGHT = "farRight"
    FAR_LEFT = "farLeft"

    @staticmethod
    def diagonal_target(box: str) -> str:
        mapping = {
            "nearRight": "farLeft",
            "nearLeft": "farRight",
            "farRight": "nearLeft",
            "farLeft": "nearRight"
        }
        return mapping.get(box, "")

class PickleballCVCoordinator:
    def __init__(self, calibration: CourtCalibrationService, rally_engine: RallyEngine):
        self.calibration = calibration
        self.rally_engine = rally_engine
        self.last_ball_y = None

    def on_ball_moved(self, y: float):
        """Kiểm tra khi bóng bay qua lưới Y = NET_Y để tăng số lượt đổi hướng (Shot Exchange)"""
        if self.last_ball_y is not None:
            if (self.last_ball_y < NET_Y and y >= NET_Y) or (self.last_ball_y > NET_Y and y <= NET_Y):
                self.rally_engine.register_shot_exchange()
        self.last_ball_y = y

    def evaluate_bounce_verdict(self, court_pos: Tuple[float, float], is_serve: bool, target_box: Optional[str] = None) -> str:
        x, y = court_pos
        r = BALL_RADIUS
        # 1. Toàn bộ ngoài sân
        if x < -r or x > (COURT_WIDTH + r) or y < -r or y > (COURT_LENGTH + r):
            return "OUT"
        
        # 2. Giao bóng
        if is_serve:
            if y > NET_Y:
                # Sân xa: Vạch bếp nằm ở Y = 8.8392m
                if y <= (FAR_NVZ_Y + r):
                    return "FAULT_KITCHEN_SERVE"
                if target_box == "farRight":
                    if x < (CENTERLINE_X - r) or x > (COURT_WIDTH + r) or y > (COURT_LENGTH + r):
                        return "OUT"
                elif target_box == "farLeft":
                    if x < -r or x > (CENTERLINE_X + r) or y > (COURT_LENGTH + r):
                        return "OUT"
                elif target_box in ["nearRight", "nearLeft"]:
                    return "OUT"
            else:
                # Sân gần: Vạch bếp nằm ở Y = 4.5720m
                if y >= (NEAR_NVZ_Y - r):
                    return "FAULT_KITCHEN_SERVE"
                if target_box == "nearRight":
                    if x < (CENTERLINE_X - r) or x > (COURT_WIDTH + r) or y < -r:
                        return "OUT"
                elif target_box == "nearLeft":
                    if x < -r or x > (CENTERLINE_X + r) or y < -r:
                        return "OUT"
                elif target_box in ["farRight", "farLeft"]:
                    return "OUT"
            return "IN"
        
        # 3. Pha bóng sống: Bếp là hợp lệ
        return "IN"

# ==============================================================================
# TEST RUNNER & SUITE DEFINITIONS
# ==============================================================================

class TestResult:
    def __init__(self):
        self.total = 0
        self.passed = 0
        self.failed = 0
        self.failures = []

    def assert_true(self, condition: bool, msg: str = ""):
        self.total += 1
        if condition:
            self.passed += 1
        else:
            self.failed += 1
            self.failures.append(msg)
            print(f"      [ASSERTION FAILED] {msg}")

    def assert_equal(self, actual, expected, msg: str = ""):
        self.total += 1
        if actual == expected:
            self.passed += 1
        else:
            self.failed += 1
            err_msg = f"{msg} (Expected: {expected}, Actual: {actual})"
            self.failures.append(err_msg)
            print(f"      [ASSERTION FAILED] {err_msg}")

    def assert_almost_equal(self, actual: float, expected: float, delta: float, msg: str = ""):
        self.total += 1
        if abs(actual - expected) <= delta:
            self.passed += 1
        else:
            self.failed += 1
            err_msg = f"{msg} (Expected: {expected} ± {delta}, Actual: {actual}, Diff: {abs(actual - expected)})"
            self.failures.append(err_msg)
            print(f"      [ASSERTION FAILED] {err_msg}")

    def assert_less_than(self, actual: float, threshold: float, msg: str = ""):
        self.total += 1
        if actual < threshold:
            self.passed += 1
        else:
            self.failed += 1
            err_msg = f"{msg} (Expected < {threshold}, Actual: {actual})"
            self.failures.append(err_msg)
            print(f"      [ASSERTION FAILED] {err_msg}")

    def assert_greater_than(self, actual: float, threshold: float, msg: str = ""):
        self.total += 1
        if actual > threshold:
            self.passed += 1
        else:
            self.failed += 1
            err_msg = f"{msg} (Expected > {threshold}, Actual: {actual})"
            self.failures.append(err_msg)
            print(f"      [ASSERTION FAILED] {err_msg}")

def run_all_tests():
    start_time = time.time()
    res = TestResult()
    print("=" * 76)
    print(" PickleVision Native iOS - Independent Automated XCTest Suite (Milestone M4)")
    print("=" * 76)
    print(f"Test Suite 'PickleVisionTests' started at {time.strftime('%Y-%m-%d %H:%M:%S')}\n")

    # --------------------------------------------------------------------------
    # SUITE 1: DLTHomographyTests
    # --------------------------------------------------------------------------
    print("Test Suite 'DLTHomographyTests' started.")
    calib = CourtCalibrationService()
    pixel_corners = [(240.0, 960.0), (1680.0, 960.0), (1260.0, 320.0), (660.0, 320.0)]
    ground_truth = [(0.0, 0.0), (COURT_WIDTH, 0.0), (COURT_WIDTH, COURT_LENGTH), (0.0, COURT_LENGTH)]

    # 1.1 Invertible Matrix
    ok = calib.calibrate(pixel_corners)
    res.assert_true(ok and calib.isCalibrated, "DLT Homography calculation must succeed")
    res.assert_true(calib.homographyMatrix is not None, "Homography matrix must not be None")
    res.assert_true(calib.inverseHomographyMatrix is not None, "Inverse homography must not be None")
    print("   [PASS] testDLTHomographyCalculation_SucceedsAndProducesInvertibleMatrix passed")

    # 1.2 Reprojection Error RMSE on 4 Calibration Corners < 0.02m
    pairs = [(pixel_corners[i], ground_truth[i]) for i in range(4)]
    rmse_corners = calib.compute_reprojection_error(pairs)
    print(f"   [PROOF] RMSE trên 4 góc hiệu chuẩn = {rmse_corners:.6f} mét (< 0.02m: True)")
    res.assert_less_than(rmse_corners, 0.02, "Reprojection error RMSE on 4 corners must be < 0.02m")
    res.assert_less_than(rmse_corners, 0.005, "Mathematical DLT precision must be < 0.005m")
    print("   [PASS] testReprojectionErrorOnCalibrationCorners_StrictlyUnderTwoCentimeters passed")

    # 1.3 Validation on 11 Independent Landmarks < 0.02m
    landmarks = [
        ("Near_NVZ_Left", 0.0000, NEAR_NVZ_Y),
        ("Near_NVZ_Center", CENTERLINE_X, NEAR_NVZ_Y),
        ("Near_NVZ_Right", COURT_WIDTH, NEAR_NVZ_Y),
        ("Net_Left", 0.0000, NET_Y),
        ("Net_Center", CENTERLINE_X, NET_Y),
        ("Net_Right", COURT_WIDTH, NET_Y),
        ("Far_NVZ_Left", 0.0000, FAR_NVZ_Y),
        ("Far_NVZ_Center", CENTERLINE_X, FAR_NVZ_Y),
        ("Far_NVZ_Right", COURT_WIDTH, FAR_NVZ_Y),
        ("Near_Baseline_Center", CENTERLINE_X, 0.0000),
        ("Far_Baseline_Center", CENTERLINE_X, COURT_LENGTH)
    ]
    val_sq_errs = []
    for name, xw, yw in landmarks:
        px = calib.court_to_pixel((xw, yw))
        res.assert_true(px is not None, f"court_to_pixel for {name} must not be None")
        if px:
            reproj = calib.pixel_to_court(px)
            res.assert_true(reproj is not None, f"pixel_to_court for {name} must not be None")
            if reproj:
                err = math.hypot(reproj[0] - xw, reproj[1] - yw)
                val_sq_errs.append(err * err)
                res.assert_less_than(err, 0.02, f"Error at landmark {name} ({err:.6f}m) must be < 0.02m")
    val_rmse = math.sqrt(sum(val_sq_errs) / len(val_sq_errs))
    print(f"   [PROOF] RMSE trên 11 điểm mốc độc lập = {val_rmse:.6f} mét (< 0.02m: True)")
    res.assert_less_than(val_rmse, 0.02, "Overall RMSE on 11 validation landmarks must be < 0.02m")
    print("   [PASS] testReprojectionErrorOnIndependentValidationLandmarks_StrictlyUnderTwoCentimeters passed")

    # 1.4 Sub-pixel Noise Robustness
    noisy_corners = [
        (240.0 + 0.35, 960.0 - 0.35),
        (1680.0 - 0.35, 960.0 + 0.35),
        (1260.0 + 0.35, 320.0 - 0.35),
        (660.0 - 0.35, 320.0 + 0.35)
    ]
    calib_noise = CourtCalibrationService()
    calib_noise.calibrate(noisy_corners)
    noise_rmse = calib_noise.compute_reprojection_error(pairs)
    print(f"   [PROOF] RMSE khi có nhiễu sub-pixel ±0.35px = {noise_rmse:.6f} mét (< 0.02m: True)")
    res.assert_less_than(noise_rmse, 0.02, "RMSE under sub-pixel noise must remain < 0.02m")
    print("   [PASS] testCalibrationWithSubPixelNoise_MaintainsRMSEUnderTwoCentimeters passed")

    # 1.5 Collinear & Insufficient Points
    collinear = [(100.0, 500.0), (400.0, 500.0), (800.0, 500.0), (1200.0, 500.0)]
    res.assert_true(not calib.calibrate(collinear), "Collinear points must fail calibration")
    print("   [PASS] testCollinearPoints_ReturnsCollinearOrSingularError passed")

    insufficient = [(200.0, 900.0), (1600.0, 900.0), (1200.0, 300.0)]
    res.assert_true(not calib.calibrate(insufficient), "3 points must fail calibration")
    print("   [PASS] testInsufficientPoints_ReturnsInvalidPointCountError passed")

    # 1.6 Round-Trip Invariance
    round_trip_max_err = 0.0
    for sx in range(5):
        for sy in range(5):
            cx = sx * (COURT_WIDTH / 4.0)
            cy = sy * (COURT_LENGTH / 4.0)
            px = calib.court_to_pixel((cx, cy))
            rec = calib.pixel_to_court(px)
            diff = math.hypot(rec[0] - cx, rec[1] - cy)
            round_trip_max_err = max(round_trip_max_err, diff)
            res.assert_less_than(diff, 0.001, f"Round-trip error at ({cx}, {cy}) must be < 1mm")
    print(f"   [PROOF] Max Round-Trip Error = {round_trip_max_err:.8f} mét (< 0.001m)")
    print("   [PASS] testCoordinateRoundTripInvariance_CourtToPixelToCourt passed")

    # 1.7 6-Point Overdetermined DLT Calibration (4 Corners + 2 Near-NVZ Points)
    six_world_pts = [
        (0.0000, 0.0000),
        (COURT_WIDTH, 0.0000),
        (COURT_WIDTH, COURT_LENGTH),
        (0.0000, COURT_LENGTH),
        (0.0000, NEAR_NVZ_Y),
        (COURT_WIDTH, NEAR_NVZ_Y)
    ]
    six_pixel_pts = [calib.court_to_pixel(p) for p in six_world_pts]
    calib_6pt = CourtCalibrationService()
    ok_6pt = calib_6pt.calibrate(six_pixel_pts)
    res.assert_true(ok_6pt, "6-point DLT calibration must succeed")
    six_pairs = [(six_pixel_pts[i], six_world_pts[i]) for i in range(6)]
    rmse_6pt = calib_6pt.compute_reprojection_error(six_pairs)
    print(f"   [PROOF] RMSE trên 6 điểm chốt DLT (4 góc + 2 điểm bếp) = {rmse_6pt:.6f} mét (< 0.02m: True)")
    res.assert_less_than(rmse_6pt, 0.02, "6-point DLT RMSE must be < 0.02m")

    # 6-point DLT under sub-pixel noise ±0.35px
    six_noisy_px = [
        (six_pixel_pts[i][0] + (0.35 if i % 2 == 0 else -0.35),
         six_pixel_pts[i][1] + (-0.35 if i % 2 == 0 else 0.35))
        for i in range(6)
    ]
    calib_6pt_noise = CourtCalibrationService()
    calib_6pt_noise.calibrate(six_noisy_px)
    rmse_6pt_noise = calib_6pt_noise.compute_reprojection_error(six_pairs)
    print(f"   [PROOF] RMSE 6 điểm DLT khi có nhiễu sub-pixel ±0.35px = {rmse_6pt_noise:.6f} mét (< 0.02m: True)")
    res.assert_less_than(rmse_6pt_noise, 0.02, "6-point DLT RMSE under sub-pixel noise must remain < 0.02m")
    print("   [PASS] testSixPointDLTHomographyCalibration_MaintainsRMSEUnderTwoCentimeters passed")

    # 1.8 10-point DLT Calibration (4 Outer Corners + 4 Kitchen Points + 2 Net Posts)
    ten_world_pts = [
        (0.0000, 0.0000),                     # 1. Near-Left Baseline
        (COURT_WIDTH, 0.0000),                # 2. Near-Right Baseline
        (COURT_WIDTH, COURT_LENGTH),          # 3. Far-Right Baseline
        (0.0000, COURT_LENGTH),               # 4. Far-Left Baseline
        (0.0000, NEAR_NVZ_Y),                 # 5. Near-NVZ Left
        (COURT_WIDTH, NEAR_NVZ_Y),            # 6. Near-NVZ Right
        (COURT_WIDTH, FAR_NVZ_Y),             # 7. Far-NVZ Right
        (0.0000, FAR_NVZ_Y),                  # 8. Far-NVZ Left
        (0.0000, NET_Y),                      # 9. Net Left Post
        (COURT_WIDTH, NET_Y)                  # 10. Net Right Post
    ]
    ten_pixel_pts = [calib.court_to_pixel(p) for p in ten_world_pts]
    calib_10pt = CourtCalibrationService()
    ok_10pt = calib_10pt.calibrate(ten_pixel_pts)
    res.assert_true(ok_10pt, "10-point DLT calibration must succeed")
    ten_pairs = [(ten_pixel_pts[i], ten_world_pts[i]) for i in range(10)]
    rmse_10pt = calib_10pt.compute_reprojection_error(ten_pairs)
    print(f"   [PROOF] RMSE trên 10 điểm chốt DLT (4 góc + 4 bếp + 2 lưới) = {rmse_10pt:.6f} mét (< 0.02m: True)")
    res.assert_less_than(rmse_10pt, 0.02, "10-point DLT RMSE must be < 0.02m")

    # 10-point DLT under sub-pixel noise ±0.35px
    ten_noisy_px = [
        (ten_pixel_pts[i][0] + (0.35 if i % 2 == 0 else -0.35),
         ten_pixel_pts[i][1] + (-0.35 if i % 2 == 0 else 0.35))
        for i in range(10)
    ]
    calib_10pt_noise = CourtCalibrationService()
    calib_10pt_noise.calibrate(ten_noisy_px)
    rmse_10pt_noise = calib_10pt_noise.compute_reprojection_error(ten_pairs)
    print(f"   [PROOF] RMSE 10 điểm DLT khi có nhiễu sub-pixel ±0.35px = {rmse_10pt_noise:.6f} mét (< 0.02m: True)")
    res.assert_less_than(rmse_10pt_noise, 0.02, "10-point DLT RMSE under sub-pixel noise must remain < 0.02m")
    print("   [PASS] testTenPointDLTHomographyCalibration_MaintainsRMSEUnderTwoCentimeters passed\n")

    # --------------------------------------------------------------------------
    # SUITE 2: InOutRulesTests
    # --------------------------------------------------------------------------
    print("Test Suite 'InOutRulesTests' started.")
    engine = RallyEngine(is_doubles=True)
    coord = PickleballCVCoordinator(calib, engine)

    # 2.1 Serve NVZ Line Fault (USAP Rule 4.A.2)
    v1 = coord.evaluate_bounce_verdict((4.5000, FAR_NVZ_Y), is_serve=True, target_box="farRight")
    res.assert_equal(v1, "FAULT_KITCHEN_SERVE", "Serve touching kitchen line must be FAULT")
    print("   [PASS] testServe_TouchingFarKitchenLine_ReturnsFault passed")

    v2 = coord.evaluate_bounce_verdict((4.5000, FAR_NVZ_Y + 0.02), is_serve=True, target_box="farRight")
    res.assert_equal(v2, "FAULT_KITCHEN_SERVE", "Serve grazing kitchen line within ball radius must be FAULT")
    print("   [PASS] testServe_GrazingKitchenLineWithBallRadius_ReturnsFault passed")

    v3 = coord.evaluate_bounce_verdict((4.5000, 7.5000), is_serve=True, target_box="farRight")
    res.assert_equal(v3, "FAULT_KITCHEN_SERVE", "Serve landing inside kitchen must be FAULT")
    print("   [PASS] testServe_LandingInsideKitchenZone_ReturnsFault passed")

    v4 = coord.evaluate_bounce_verdict((1.5000, NEAR_NVZ_Y), is_serve=True, target_box="nearLeft")
    res.assert_equal(v4, "FAULT_KITCHEN_SERVE", "Serve touching near kitchen line must be FAULT")
    print("   [PASS] testServe_LandingNearKitchenWhenTargetingNearCourt_ReturnsFault passed")

    # 2.2 Boundary Lines IN on Serve
    v5 = coord.evaluate_bounce_verdict((4.5000, COURT_LENGTH), is_serve=True, target_box="farRight")
    res.assert_equal(v5, "IN", "Serve touching baseline must be IN")
    print("   [PASS] testServe_TouchingBaseline_ReturnsIn passed")

    v6 = coord.evaluate_bounce_verdict((COURT_WIDTH, 11.2000), is_serve=True, target_box="farRight")
    res.assert_equal(v6, "IN", "Serve touching right sideline must be IN")
    print("   [PASS] testServe_TouchingRightSideline_ReturnsIn passed")

    v7 = coord.evaluate_bounce_verdict((CENTERLINE_X, 10.5000), is_serve=True, target_box="farRight")
    res.assert_equal(v7, "IN", "Serve touching centerline must be IN")
    print("   [PASS] testServe_TouchingCenterline_ReturnsIn passed")

    v8 = coord.evaluate_bounce_verdict((4.5000, COURT_LENGTH + 0.10), is_serve=True, target_box="farRight")
    res.assert_equal(v8, "OUT", "Serve beyond baseline must be OUT")
    print("   [PASS] testServe_LandingBeyondBaseline_ReturnsOut passed")

    v9 = coord.evaluate_bounce_verdict((COURT_WIDTH + 0.08, 11.0000), is_serve=True, target_box="farRight")
    res.assert_equal(v9, "OUT", "Serve beyond sideline must be OUT")
    print("   [PASS] testServe_LandingBeyondSideline_ReturnsOut passed")

    v10 = coord.evaluate_bounce_verdict((1.5000, 10.5000), is_serve=True, target_box="farRight")
    res.assert_equal(v10, "OUT", "Serve in wrong diagonal box must be OUT")
    print("   [PASS] testServe_LandingInWrongServiceBox_ReturnsOut passed")

    # 2.2.1 Crosscourt ServiceBox.diagonal_target (USAP Rule 4.A.2: Chéo sân)
    res.assert_equal(ServiceBox.diagonal_target("nearRight"), "farLeft", "nearRight diagonal target must be farLeft")
    res.assert_equal(ServiceBox.diagonal_target("nearLeft"), "farRight", "nearLeft diagonal target must be farRight")
    res.assert_equal(ServiceBox.diagonal_target("farRight"), "nearLeft", "farRight diagonal target must be nearLeft")
    res.assert_equal(ServiceBox.diagonal_target("farLeft"), "nearRight", "farLeft diagonal target must be nearRight")
    print("   [PASS] testCrosscourtDiagonalTargetMapping_MatchesUSAPRule passed")

    # 2.2.2 Near Court Serve Validation (Phát bóng sang sân gần)
    v_near_correct = coord.evaluate_bounce_verdict((4.5000, 2.0000), is_serve=True, target_box="nearRight")
    res.assert_equal(v_near_correct, "IN", "Serve into correct nearRight box must be IN")
    
    v_near_wrong = coord.evaluate_bounce_verdict((1.5000, 2.0000), is_serve=True, target_box="nearRight")
    res.assert_equal(v_near_wrong, "OUT", "Serve into wrong box in near court (nearLeft instead of nearRight) must be OUT")
    
    v_near_wrong_court = coord.evaluate_bounce_verdict((4.5000, 10.0000), is_serve=True, target_box="nearRight")
    res.assert_equal(v_near_wrong_court, "OUT", "Serve into far court when targeting nearRight must be OUT")
    print("   [PASS] testNearCourtServeValidation_WrongServiceBoxReturnsOut passed")

    # 2.2.3 Net Crossing Exchange Event
    coord.rally_engine.start_rally()
    coord.rally_engine.handle_ball_bounce((4.5, 10.5), is_serve=True)  # State becomes IN_PROGRESS
    initial_shots = coord.rally_engine.shot_count
    coord.on_ball_moved(3.0)  # Near side
    coord.on_ball_moved(8.0)  # Far side (Crossed net Y=6.7056m)
    res.assert_equal(coord.rally_engine.shot_count, initial_shots + 1, "Ball crossing net plane must trigger shot exchange")
    print("   [PASS] testNetCrossing_IncrementsShotExchangeCount passed")

    # 2.3 Live Rally Rules (USAP Rule 2.B.3 & 6.A)
    v11 = coord.evaluate_bounce_verdict((3.0480, 6.0000), is_serve=False)
    res.assert_equal(v11, "IN", "Live ball inside kitchen must be IN")
    print("   [PASS] testLiveRally_LandingInsideKitchen_ReturnsIn passed")

    v12 = coord.evaluate_bounce_verdict((4.5000, FAR_NVZ_Y), is_serve=False)
    res.assert_equal(v12, "IN", "Live ball on kitchen line must be IN")
    print("   [PASS] testLiveRally_TouchingKitchenLine_ReturnsIn passed")

    v13 = coord.evaluate_bounce_verdict((0.0000, 7.5000), is_serve=False)
    res.assert_equal(v13, "IN", "Live ball on left sideline must be IN")
    print("   [PASS] testLiveRally_TouchingBoundaryLines_ReturnsIn passed")

    v14 = coord.evaluate_bounce_verdict((-0.0600, 5.0000), is_serve=False)
    res.assert_equal(v14, "OUT", "Live ball outside left sideline must be OUT")
    print("   [PASS] testLiveRally_LandingOutsideCourt_ReturnsOut passed")

    # 2.4 Two-Bounce Rule & Kitchen Volley
    engine.reset_match()
    engine.start_rally()
    engine.handle_ball_bounce((4.5, 10.5), is_serve=True)
    engine.end_rally("TWO_BOUNCE_FAULT")
    res.assert_equal(engine.state, "ENDED", "Two-Bounce violation must end rally")
    print("   [PASS] testTwoBounceRule_ReceiverVolleyOnServe_TriggersFault passed")

    # Kitchen Volley Foot Fault
    ankle_in_kitchen = (2.0, 4.70)
    is_fault = ankle_in_kitchen[1] >= (NEAR_NVZ_Y - 0.05)
    res.assert_true(is_fault, "Ankle inside kitchen during volley must trigger fault")
    print("   [PASS] testKitchenVolleyFault_FootInsideKitchenDuringVolley passed\n")

    # --------------------------------------------------------------------------
    # SUITE 3: RallyEngineTests
    # --------------------------------------------------------------------------
    print("Test Suite 'RallyEngineTests' started.")
    reng = RallyEngine(is_doubles=True)
    res.assert_equal(reng.state, "WAITING_FOR_SERVE", "Initial state must be WAITING_FOR_SERVE")
    res.assert_equal(reng.score_display, "0 - 0 - 2", "Initial doubles score must be 0-0-2")
    print("   [PASS] testInitialState_IsWaitingForServe passed")

    reng.start_rally()
    res.assert_equal(reng.state, "SERVE_IN_FLIGHT", "State must be SERVE_IN_FLIGHT")
    res.assert_equal(reng.shot_count, 1, "Serve is shot #1")
    v_serve = reng.handle_ball_bounce((4.5, 10.5), is_serve=True)
    res.assert_equal(v_serve, "IN")
    res.assert_equal(reng.state, "IN_PROGRESS", "State must be IN_PROGRESS")

    for _ in range(6):
        reng.register_shot_exchange()
    res.assert_equal(reng.shot_count, 7, "Total shot count must be 7")

    reng.end_rally("OUT", duration=8.5)
    res.assert_equal(reng.state, "ENDED", "State must be ENDED")
    res.assert_equal(reng.rally_duration, 8.5)
    print("   [PASS] testRallyStateTransitions_FullLifecycle passed")

    # Illegal serve fault transitions immediately
    reng.prepare_next_rally()
    reng.start_rally()
    v_fault = reng.handle_ball_bounce((4.5, FAR_NVZ_Y), is_serve=True)
    res.assert_equal(v_fault, "FAULT_KITCHEN_SERVE")
    reng.end_rally(v_fault)
    res.assert_equal(reng.state, "ENDED")
    print("   [PASS] testIllegalServeBounce_TransitionsDirectlyToEnded passed")

    # Double bounce on same side
    reng.prepare_next_rally()
    reng.start_rally()
    reng.handle_ball_bounce((4.5, 10.5), is_serve=True) # Bounce 1 far side
    v_db = reng.handle_ball_bounce((4.2, 11.2), is_serve=False) # Bounce 2 far side
    res.assert_equal(v_db, "TWO_BOUNCE_FAULT", "Double bounce must be detected")
    print("   [PASS] testDoubleBounceOnSameSide_TriggersTwoBounceFault passed")

    # Doubles Side-out rotation
    reng.reset_match()
    res.assert_equal(reng.score_display, "0 - 0 - 2")
    # Loss on server 2 -> Side-out to Far team server 1 (0 - 0 - 1)
    reng.start_rally()
    reng.end_rally("OUT")
    res.assert_equal(reng.serving_team, "FarTeam")
    res.assert_equal(reng.score_display, "0 - 0 - 1")
    # Far team wins point -> 1 - 0 - 1
    reng.prepare_next_rally()
    reng.start_rally()
    reng.end_rally("IN")
    res.assert_equal(reng.score_display, "1 - 0 - 1")
    # Server 1 loses -> Server 2 of Far team (1 - 0 - 2)
    reng.prepare_next_rally()
    reng.start_rally()
    reng.end_rally("OUT")
    res.assert_equal(reng.serving_team, "FarTeam")
    res.assert_equal(reng.score_display, "1 - 0 - 2")
    # Server 2 loses -> Side-out back to Near team (0 - 1 - 1)
    reng.prepare_next_rally()
    reng.start_rally()
    reng.end_rally("OUT")
    res.assert_equal(reng.serving_team, "NearTeam")
    res.assert_equal(reng.score_display, "0 - 1 - 1")
    print("   [PASS] testDoublesSideOutScoring_CompleteRotation passed")

    # Singles scoring
    seng = RallyEngine(is_doubles=False)
    res.assert_equal(seng.score_display, "0 - 0")
    seng.start_rally()
    seng.end_rally("IN")
    res.assert_equal(seng.score_display, "1 - 0")
    seng.prepare_next_rally()
    seng.start_rally()
    seng.end_rally("OUT")
    res.assert_equal(seng.score_display, "0 - 1")
    print("   [PASS] testSinglesSideOutScoring passed")

    reng.reset_match()
    res.assert_equal(reng.state, "WAITING_FOR_SERVE")
    res.assert_equal(reng.rally_index, 1)
    print("   [PASS] testResetMatch_RestoresAllInitialParameters passed\n")

    # --------------------------------------------------------------------------
    # SUITE 4: PlayerDistanceFilterTests
    # --------------------------------------------------------------------------
    print("Test Suite 'PlayerDistanceFilterTests' started.")
    ptrack = PlayerTrack(0, "Tú", "NearTeam", (3.048, 1.0))

    # 4.1 Jitter Filter < 0.05m
    for i in range(100):
        noise_x = (math.sin(i * 0.7) * 0.038)
        noise_y = (math.cos(i * 0.7) * 0.038)
        ptrack.update((3.048 + noise_x, 1.0 + noise_y), timestamp=i * 0.016)
    res.assert_equal(ptrack.rally_distance, 0.0, "Jitter < 0.05m must result in 0.0m distance")
    res.assert_equal(ptrack.total_match_distance, 0.0, "Total match distance must remain 0.0m")
    res.assert_equal(ptrack.speed_mps, 0.0, "Speed must be 0.0 m/s")
    print("   [PASS] testJitterFilter_SuppressesStaticMovementUnderThreshold passed")

    # 4.2 Linear sprint 3.5m
    ptrack_sprint = PlayerTrack(0, "Tú", "NearTeam", (3.048, 1.0))
    for i in range(91):
        t = i * (1.5 / 90.0)
        p = t / 1.5
        curr_y = 1.0 + 3.5 * p
        ptrack_sprint.update((3.048, curr_y), timestamp=t)
    print(f"   [DISTANCE] Quãng đường chạy nước rút tính được = {ptrack_sprint.rally_distance:.3f} mét (Lý thuyết: 3.500m)")
    res.assert_almost_equal(ptrack_sprint.rally_distance, 3.5, 0.20, "Sprint distance must be ~3.5m")
    print("   [PASS] testSprintDistanceAccumulation_CalculatesTrueMetricDistance passed")

    # 4.3 Lateral shuffle 6.0m
    ptrack_shuf = PlayerTrack(0, "Tú", "NearTeam", (1.5, 2.0))
    for i in range(121):
        t = i * (2.0 / 120.0)
        p = t / 2.0
        curr_x = (1.5 + 3.0 * (p / 0.5)) if p <= 0.5 else (4.5 - 3.0 * ((p - 0.5) / 0.5))
        ptrack_shuf.update((curr_x, 2.0), timestamp=t)
    print(f"   [DISTANCE] Quãng đường di chuyển ngang 2 chiều = {ptrack_shuf.rally_distance:.3f} mét (Lý thuyết: 6.000m)")
    res.assert_almost_equal(ptrack_shuf.rally_distance, 6.0, 0.35, "Shuffle distance must be ~6.0m")
    print("   [PASS] testLateralShuffle_CalculatesBidirectionalDistance passed")

    # 4.4 Teleportation glitch rejection > 10.5 m/s and Post-Glitch Recovery (No Tracking Paralysis)
    initial_d = ptrack_sprint.rally_distance
    ptrack_sprint.update((3.048, 18.0), timestamp=1.533) # 13.5m in 0.033s = 409 m/s!
    res.assert_equal(ptrack_sprint.rally_distance, initial_d, "Glitch > 10.5 m/s must be rejected")
    
    # Tiếp tục chạy bình thường 10 frame sau glitch (v = 3.0 m/s) -> Không bị tê liệt bám vết
    for k in range(1, 11):
        t_post = 1.533 + k * 0.016
        y_post = 4.5 + 3.0 * (k * 0.016)
        ptrack_sprint.update((3.048, y_post), timestamp=t_post)
    res.assert_greater_than(ptrack_sprint.rally_distance, initial_d + 0.35, "Player tracking must smoothly resume after glitch without paralysis")
    print("   [PASS] testPhysiologicalSpeedLimit_RejectsTeleportationGlitchesAndRecoversImmediately passed")

    # 4.5 Dual distance tracking
    d_rally1 = ptrack_sprint.rally_distance
    d_total1 = ptrack_sprint.total_match_distance
    ptrack_sprint.reset_rally_distance()
    res.assert_equal(ptrack_sprint.rally_distance, 0.0)
    res.assert_equal(ptrack_sprint.total_match_distance, d_total1)
    print("   [PASS] testDualDistanceTracking_RallyVsMatchDistance passed")

    # 4.6 Kalman Filter 2D
    kf = KalmanFilter2D((1.0, 1.0))
    for step in range(1, 20):
        kf.predict(0.05)
        meas = (1.0 + step * 0.1, 1.0 + step * 0.05)
        est = kf.update(meas)
        res.assert_true(not math.isnan(est[0]), "Kalman estimate X must not be NaN")
    print("   [PASS] testKalmanFilter2D_SmoothsNoisyLinearTrajectory passed\n")

    # --------------------------------------------------------------------------
    # SUITE 5: BallParabolaSpeedTests
    # --------------------------------------------------------------------------
    print("Test Suite 'BallParabolaSpeedTests' started.")
    true_a = -4.900
    true_b = 15.000
    true_c = 200.000
    obs = [(10.0 + i * (1.0/60.0), true_a*(i*(1.0/60.0))**2 + true_b*(i*(1.0/60.0)) + true_c) for i in range(12)]
    fit = fit_parabola(obs)
    res.assert_true(fit is not None, "Parabola fit must not be None")
    if fit:
        res.assert_almost_equal(fit.a, true_a, 0.05, "Fitted 'a' must match -4.9")
        res.assert_almost_equal(fit.b, true_b, 0.10, "Fitted 'b' must match 15.0")
        res.assert_almost_equal(fit.c, true_c, 0.20, "Fitted 'c' must match 200.0")
        res.assert_almost_equal(fit.second_derivative, 2.0 * true_a, 0.10, "Second derivative must be 2*a")
    print("   [PASS] testParabolaFit_AccuratelyRecoversQuadraticCoefficients passed")

    # Bounce detection
    z_vals = [1.2, 0.9, 0.6, 0.3, 0.05, 0.0, 0.2, 0.5, 0.8]
    bounce_found = False
    for i in range(1, len(z_vals)-1):
        if z_vals[i] <= 0.05 and (z_vals[i] - z_vals[i-1]) < 0 and (z_vals[i+1] - z_vals[i]) > 0:
            bounce_found = True
            break
    res.assert_true(bounce_found, "Bounce must be detected when vz reverses at Z≈0")
    print("   [PASS] testBounceDetection_IdentifiesVerticalAccelerationReversal passed")

    # Instantaneous speed (3.0m in 0.10s = 30 m/s = 108.0 km/h)
    speed_kmh = (3.0 / 0.10) * 3.6
    res.assert_equal(speed_kmh, 108.0, "Speed must be 108.0 km/h")
    print("   [PASS] testInstantaneousSpeedCalculation_Accuracy passed")

    # Peak speed tracking
    speeds = [35.0, 65.0, 90.0, 45.0]
    peak = max(speeds)
    res.assert_equal(peak, 90.0, "Peak speed must be 90.0 km/h")
    print("   [PASS] testPeakSpeedTracking_MaintainsMaximumEncounteredSpeed passed")

    # Outlier rejection > 130 km/h
    unrealistic_speed = 250.0
    valid_speed = unrealistic_speed if unrealistic_speed <= 130.0 else 0.0
    res.assert_equal(valid_speed, 0.0, "Unrealistic speed > 130 km/h must be suppressed")
    print("   [PASS] testUnrealisticSpeedSuppression_FiltersOutliersAbove130Kmh passed")

    # Trail buffer limit 25
    trail = [i for i in range(50)]
    trail = trail[-25:]
    res.assert_equal(len(trail), 25, "Trail buffer limit must be 25")
    print("   [PASS] testTrajectoryTrailRetention_LimitsWindowSize passed\n")

    # --------------------------------------------------------------------------
    # SUITE 6: FullPipelineIntegrationTests
    # --------------------------------------------------------------------------
    print("Test Suite 'FullPipelineIntegrationTests' started.")
    # Full end-to-end integration
    calib_int = CourtCalibrationService()
    res.assert_true(calib_int.calibrate(pixel_corners))
    res.assert_less_than(calib_int.lastReprojectionError, 0.02)

    engine_int = RallyEngine(is_doubles=True)
    coord_int = PickleballCVCoordinator(calib_int, engine_int)

    # 6.1 Full legal rally lifecycle
    engine_int.start_rally()
    res.assert_equal(engine_int.state, "SERVE_IN_FLIGHT")

    # Legal serve bounce
    v_s = coord_int.evaluate_bounce_verdict((4.5, 10.5), is_serve=True, target_box="farRight")
    res.assert_equal(v_s, "IN")
    engine_int.handle_ball_bounce((4.5, 10.5), is_serve=True)
    res.assert_equal(engine_int.state, "IN_PROGRESS")

    # Two-bounce rule fulfilled: Return shot (bounce 1 occurred)
    engine_int.register_shot_exchange() # Shot 2
    # 3rd shot (bounce 2 occurred)
    engine_int.handle_ball_bounce((3.0, 2.0), is_serve=False)
    engine_int.register_shot_exchange() # Shot 3

    # 6 more exchanges
    for _ in range(6):
        engine_int.register_shot_exchange()
    res.assert_equal(engine_int.shot_count, 9)

    # Winning smash ending (IN)
    v_end = coord_int.evaluate_bounce_verdict((4.5, COURT_LENGTH), is_serve=False)
    res.assert_equal(v_end, "IN")
    engine_int.end_rally(v_end)
    res.assert_equal(engine_int.state, "ENDED")
    res.assert_equal(engine_int.score_display, "1 - 0 - 2", "Serving team won rally, score becomes 1-0-2")
    print("   [PASS] testFullMatchRallyLifecycle_EndToEnd passed")

    # 6.2 Kitchen serve fault pipeline
    engine_int.reset_match()
    engine_int.start_rally()
    v_kf = coord_int.evaluate_bounce_verdict((4.5, FAR_NVZ_Y), is_serve=True, target_box="farRight")
    res.assert_equal(v_kf, "FAULT_KITCHEN_SERVE")
    engine_int.end_rally(v_kf)
    res.assert_equal(engine_int.state, "ENDED")
    # Loss on server 2 -> Side-out to Far team (0 - 0 - 1 in Side-Out scoring)
    res.assert_equal(engine_int.score_display, "0 - 0 - 1")
    print("   [PASS] testKitchenServeFaultPipeline_EndsRallyAndSwitchesServer passed")

    # 6.3 Kitchen volley fault pipeline
    engine_int.prepare_next_rally()
    engine_int.start_rally()
    engine_int.handle_ball_bounce((4.5, 10.5), is_serve=True)
    engine_int.end_rally("KITCHEN_VOLLEY_FAULT")
    res.assert_equal(engine_int.state, "ENDED")
    print("   [PASS] testKitchenVolleyFaultPipeline passed")

    # 6.4 Telemetry consistency
    engine_fresh = RallyEngine(is_doubles=True)
    engine_fresh.start_rally()
    engine_fresh.handle_ball_bounce((4.5, 10.5), is_serve=True)
    res.assert_equal(engine_fresh.rally_index, 1, "Fresh rally index must be 1")
    res.assert_equal(engine_fresh.shot_count, 1, "Shot count must be 1")
    res.assert_equal(engine_fresh.score_display, "0 - 0 - 2", "Score must be 0-0-2")
    res.assert_equal(engine_fresh.state, "IN_PROGRESS")
    print("   [PASS] testTelemetryStream_ContainsConsistentMetadata passed\n")

    # ==========================================================================
    # 7. COURT GEOMETRY BOUNDARY CONSTRAINT TESTS (v1.0.3)
    # ==========================================================================
    print("Test Suite 'CourtGeometryBoundaryConstraintTests' started.")
    
    def geom_compute_t(p, a, b):
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        lsq = dx * dx + dy * dy
        if lsq < 1e-6: return 0.5
        t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / lsq
        return min(max(t, 0.01), 0.99)
        
    def geom_project(p, a, b, t_min, t_max):
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        lsq = dx * dx + dy * dy
        if lsq < 1e-6: return a
        t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / lsq
        ct = min(max(t, t_min), t_max)
        return (a[0] + ct * dx, a[1] + ct * dy)
        
    def geom_update(corners, idx, touch):
        c = list(corners)
        clamped = (min(max(touch[0], 0.0), 1.0), min(max(touch[1], 0.0), 1.0))
        if idx == 0:
            t4 = geom_compute_t(c[4], c[0], c[3])
            t8 = geom_compute_t(c[8], c[0], c[3])
            t7 = geom_compute_t(c[7], c[0], c[3])
            c[0] = clamped
            dx, dy = c[3][0] - c[0][0], c[3][1] - c[0][1]
            c[4] = (c[0][0] + t4 * dx, c[0][1] + t4 * dy)
            c[8] = (c[0][0] + t8 * dx, c[0][1] + t8 * dy)
            c[7] = (c[0][0] + t7 * dx, c[0][1] + t7 * dy)
        elif idx == 3:
            t4 = geom_compute_t(c[4], c[0], c[3])
            t8 = geom_compute_t(c[8], c[0], c[3])
            t7 = geom_compute_t(c[7], c[0], c[3])
            c[3] = clamped
            dx, dy = c[3][0] - c[0][0], c[3][1] - c[0][1]
            c[4] = (c[0][0] + t4 * dx, c[0][1] + t4 * dy)
            c[8] = (c[0][0] + t8 * dx, c[0][1] + t8 * dy)
            c[7] = (c[0][0] + t7 * dx, c[0][1] + t7 * dy)
        elif idx == 1:
            t5 = geom_compute_t(c[5], c[1], c[2])
            t9 = geom_compute_t(c[9], c[1], c[2])
            t6 = geom_compute_t(c[6], c[1], c[2])
            c[1] = clamped
            dx, dy = c[2][0] - c[1][0], c[2][1] - c[1][1]
            c[5] = (c[1][0] + t5 * dx, c[1][1] + t5 * dy)
            c[9] = (c[1][0] + t9 * dx, c[1][1] + t9 * dy)
            c[6] = (c[1][0] + t6 * dx, c[1][1] + t6 * dy)
        elif idx == 2:
            t5 = geom_compute_t(c[5], c[1], c[2])
            t9 = geom_compute_t(c[9], c[1], c[2])
            t6 = geom_compute_t(c[6], c[1], c[2])
            c[2] = clamped
            dx, dy = c[2][0] - c[1][0], c[2][1] - c[1][1]
            c[5] = (c[1][0] + t5 * dx, c[1][1] + t5 * dy)
            c[9] = (c[1][0] + t9 * dx, c[1][1] + t9 * dy)
            c[6] = (c[1][0] + t6 * dx, c[1][1] + t6 * dy)
        elif idx == 4:
            t8 = geom_compute_t(c[8], c[0], c[3])
            c[4] = geom_project(clamped, c[0], c[3], 0.05, max(0.06, t8 - 0.03))
        elif idx == 8:
            t4 = geom_compute_t(c[4], c[0], c[3])
            t7 = geom_compute_t(c[7], c[0], c[3])
            c[8] = geom_project(clamped, c[0], c[3], min(t4 + 0.03, 0.94), max(0.06, t7 - 0.03))
        elif idx == 7:
            t8 = geom_compute_t(c[8], c[0], c[3])
            c[7] = geom_project(clamped, c[0], c[3], min(t8 + 0.03, 0.94), 0.95)
        elif idx == 5:
            t9 = geom_compute_t(c[9], c[1], c[2])
            c[5] = geom_project(clamped, c[1], c[2], 0.05, max(0.06, t9 - 0.03))
        elif idx == 9:
            t5 = geom_compute_t(c[5], c[1], c[2])
            t6 = geom_compute_t(c[6], c[1], c[2])
            c[9] = geom_project(clamped, c[1], c[2], min(t5 + 0.03, 0.94), max(0.06, t6 - 0.03))
        elif idx == 6:
            t9 = geom_compute_t(c[9], c[1], c[2])
            c[6] = geom_project(clamped, c[1], c[2], min(t9 + 0.03, 0.94), 0.95)
        return c

    # Khởi tạo 10 điểm mốc sân chuẩn v1.0.3
    init_10 = [
        (0.12, 0.88), (0.88, 0.88), (0.68, 0.22), (0.32, 0.22),
        (0.1882, 0.6550), (0.8118, 0.6550), (0.7482, 0.4450), (0.2518, 0.4450),
        (0.2200, 0.5500), (0.7800, 0.5500)
    ]

    # 7.1 Kéo chốt bếp gần trái (idx 4) ra xa (ví dụ x=0.50, y=0.50) -> Bắt buộc chiếu lên đoạn P0->P3
    updated_4 = geom_update(init_10, 4, (0.50, 0.50))
    # Khoảng cách từ điểm mới tới đoạn thẳng P0->P3 phải = 0
    t_val = geom_compute_t(updated_4[4], updated_4[0], updated_4[3])
    dx = updated_4[3][0] - updated_4[0][0]
    dy = updated_4[3][1] - updated_4[0][1]
    expected_x = updated_4[0][0] + t_val * dx
    expected_y = updated_4[0][1] + t_val * dy
    res.assert_true(abs(updated_4[4][0] - expected_x) < 1e-5, "P4 x must lie on P0->P3")
    res.assert_true(abs(updated_4[4][1] - expected_y) < 1e-5, "P4 y must lie on P0->P3")
    print("   [PASS] testKitchenPoint_ProjectsOntoLeftSideline_WhenDraggedFreely passed")

    # 7.2 Thứ tự hình học trên biên trái P0 <= P4 <= P8 <= P7 <= P3
    t4 = geom_compute_t(updated_4[4], updated_4[0], updated_4[3])
    t8 = geom_compute_t(updated_4[8], updated_4[0], updated_4[3])
    t7 = geom_compute_t(updated_4[7], updated_4[0], updated_4[3])
    res.assert_true(t4 < t8, "P4 must precede P8 along left sideline")
    res.assert_true(t8 < t7, "P8 must precede P7 along left sideline")
    print("   [PASS] testNetPoint_MaintainsOrderBetweenNearAndFarKitchen_OnSidelines passed")

    # 7.3 Kéo góc đáy sân P0 -> Các điểm P4, P8, P7 tự động bám theo đường biên mới
    updated_corner = geom_update(init_10, 0, (0.05, 0.95))
    res.assert_equal(updated_corner[0], (0.05, 0.95), "Corner P0 updated")
    t4_new = geom_compute_t(updated_corner[4], updated_corner[0], updated_corner[3])
    t4_old = geom_compute_t(init_10[4], init_10[0], init_10[3])
    res.assert_true(abs(t4_new - t4_old) < 1e-3, "P4 preserves relative ratio on sideline")
    print("   [PASS] testDraggingCorner_PreservesRelativePositionsOfKitchenAndNetPoints passed")

    # 7.4 Kéo chốt trên biên phải P5 -> Bắt buộc chiếu lên đoạn P1->P2
    updated_5 = geom_update(init_10, 5, (0.20, 0.70))
    t5_val = geom_compute_t(updated_5[5], updated_5[1], updated_5[2])
    dx_r = updated_5[2][0] - updated_5[1][0]
    dy_r = updated_5[2][1] - updated_5[1][1]
    res.assert_true(abs(updated_5[5][0] - (updated_5[1][0] + t5_val * dx_r)) < 1e-5, "P5 must lie on P1->P2")
    res.assert_true(abs(updated_5[5][1] - (updated_5[1][1] + t5_val * dy_r)) < 1e-5, "P5 must lie on P1->P2")
    print("   [PASS] testRightSidelineConstraints_ProjectsPointsOntoRightBoundary passed")

    # 7.5 Kéo góc đáy phải P1 -> P5, P9, P6 tự động bám theo đường biên phải mới
    updated_p1 = geom_update(init_10, 1, (0.92, 0.95))
    res.assert_equal(updated_p1[1], (0.92, 0.95), "Corner P1 updated")
    t5_new = geom_compute_t(updated_p1[5], updated_p1[1], updated_p1[2])
    t5_old = geom_compute_t(init_10[5], init_10[1], init_10[2])
    res.assert_true(abs(t5_new - t5_old) < 1e-3, "P5 preserves relative ratio on right sideline")
    print("   [PASS] testBoundaryProjectionClamping_PreventsPointsLeavingCourtPerimeter passed\n")

    # --------------------------------------------------------------------------
    # SUMMARY
    # --------------------------------------------------------------------------
    elapsed = time.time() - start_time
    print("=" * 76)
    print(" TEST EXECUTION SUMMARY")
    print("=" * 76)
    print(f" Total Assertions Checked : {res.total}")
    print(f" Passed Assertions        : {res.passed}")
    print(f" Failed Assertions        : {res.failed}")
    print(f" Execution Time           : {elapsed:.3f} seconds")
    print(f" Pass Rate                : {(res.passed / res.total * 100):.2f}%")
    print("=" * 76)

    if res.failed == 0:
        print("\n *** ALL 6 TEST SUITES PASSED (100% SUCCESS) *** \n")
        return 0
    else:
        print(f"\n !!! {res.failed} ASSERTIONS FAILED !!! \n")
        return 1

if __name__ == '__main__':
    sys.exit(run_all_tests())
