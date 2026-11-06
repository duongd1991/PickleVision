#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Adversarial Empirical Verification Harness for PickleVision
Author: Challenger 1 (critic, specialist)
Tasks:
1. DLT Homography stress test:
   - Steep camera tilt angles (low/high pitch, camera height variation, corner angles)
   - Sub-pixel noise from 0.1px to 0.5px across Monte-Carlo trials
   - Verification of reprojection error < 0.02m (< 2cm) across corners, landmarks, and dense court grid.
2. USA Pickleball In/Out Rule Engine stress test:
   - Sát mép vạch bếp (Y = 8.8392 ± 0.001m / 2.1336m from net) with ball radius r = 0.037m.
   - Confirm serve touching kitchen line is 100% FAULT.
   - Confirm live rally ball in kitchen is 100% IN.
   - Boundary lines, centerline, service boxes.
"""

import sys
import math
import random
import io
from typing import List, Tuple, Optional, Dict

if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')


# USA Pickleball Geometry
COURT_WIDTH = 6.0960       # 20.0 ft
COURT_LENGTH = 13.4112     # 44.0 ft
NET_Y = 6.7056             # 13.4112 / 2
NVZ_LENGTH = 2.1336        # 7.0 ft
NEAR_NVZ_Y = NET_Y - NVZ_LENGTH # 4.5720m
FAR_NVZ_Y = NET_Y + NVZ_LENGTH  # 8.8392m
CENTERLINE_X = COURT_WIDTH / 2.0 # 3.0480m
LINE_WIDTH = 0.0508        # 2 inches
BALL_RADIUS = 0.0370       # ~3.7 cm

# ------------------------------------------------------------------------------
# 1. Linear Algebra & DLT Implementation (mirroring PickleVision / Accelerate LAPACK)
# ------------------------------------------------------------------------------

def normalize_hartley(pts: List[Tuple[float, float]]) -> Tuple[List[List[float]], List[Tuple[float, float]]]:
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
    a, b, c = A[0]
    d, e, f = A[1]
    g, h, i = A[2]
    det = a*(e*i - f*h) - b*(d*i - f*g) + c*(d*h - e*g)
    if abs(det) < 1e-13:
        return None
    invdet = 1.0 / det
    return [
        [(e*i - f*h)*invdet, (c*h - b*i)*invdet, (b*f - c*e)*invdet],
        [(f*g - d*i)*invdet, (a*i - c*g)*invdet, (c*d - a*f)*invdet],
        [(d*h - e*g)*invdet, (b*g - a*h)*invdet, (a*e - b*d)*invdet]
    ]

def mat_mul_3x3(A: List[List[float]], B: List[List[float]]) -> List[List[float]]:
    C = [[0.0]*3 for _ in range(3)]
    for i in range(3):
        for j in range(3):
            C[i][j] = sum(A[i][k] * B[k][j] for k in range(3))
    return C

def jacobi_svd_smallest(A: List[List[float]]) -> List[float]:
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
    for sweep in range(80):
        max_off = 0.0
        p, q = 0, 1
        for i in range(n):
            for j in range(i+1, n):
                if abs(ATA[i][j]) > max_off:
                    max_off = abs(ATA[i][j])
                    p, q = i, j
        if max_off < 1e-15:
            break
        diff = ATA[q][q] - ATA[p][p]
        if abs(ATA[p][q]) < 1e-16:
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

class DLTHomographySolver:
    def __init__(self, use_hartley: bool = True):
        self.use_hartley = use_hartley
        self.H: Optional[List[List[float]]] = None
        self.invH: Optional[List[List[float]]] = None

    def calibrate(self, image_pts: List[Tuple[float, float]], world_pts: List[Tuple[float, float]]) -> bool:
        if len(image_pts) < 4 or len(world_pts) < 4:
            return False
        
        # Collinear check on first 3 points
        p0, p1, p2 = image_pts[:3]
        cross = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])
        if abs(cross) < 1e-4:
            return False

        if self.use_hartley:
            T_img, norm_img = normalize_hartley(image_pts[:4])
            T_world, norm_world = normalize_hartley(world_pts[:4])
        else:
            T_img = [[1,0,0],[0,1,0],[0,0,1]]
            T_world = [[1,0,0],[0,1,0],[0,0,1]]
            norm_img = image_pts[:4]
            norm_world = world_pts[:4]

        A = []
        for i in range(4):
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
        self.H = H
        self.invH = invH
        return True

    def pixel_to_court(self, pixel: Tuple[float, float]) -> Optional[Tuple[float, float]]:
        if not self.H:
            return None
        u, v = pixel
        w = self.H[2][0]*u + self.H[2][1]*v + self.H[2][2]
        if abs(w) < 1e-9:
            return None
        x = (self.H[0][0]*u + self.H[0][1]*v + self.H[0][2]) / w
        y = (self.H[1][0]*u + self.H[1][1]*v + self.H[1][2]) / w
        return (x, y)

    def court_to_pixel(self, court: Tuple[float, float]) -> Optional[Tuple[float, float]]:
        if not self.invH:
            return None
        x, y = court
        w = self.invH[2][0]*x + self.invH[2][1]*y + self.invH[2][2]
        if abs(w) < 1e-9:
            return None
        u = (self.invH[0][0]*x + self.invH[0][1]*y + self.invH[0][2]) / w
        v = (self.invH[1][0]*x + self.invH[1][1]*y + self.invH[1][2]) / w
        return (u, v)

    def compute_rmse(self, pairs: List[Tuple[Tuple[float, float], Tuple[float, float]]]) -> float:
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


# ------------------------------------------------------------------------------
# 2. Camera Projector Model (Pinhole 3D -> 2D) for Arbitrary Tilt Angles
# ------------------------------------------------------------------------------

class CameraProjector:
    """
    Mô hình Camera Pinhole 3D -> 2D 1080p:
    - Camera đặt tại (cam_x, cam_y, cam_z)
    - Pitch: góc chúc xuống (độ)
    - Yaw: góc xoay ngang (độ)
    - Roll: góc nghiêng trục quang (độ)
    - Focal length f_pixels (ví dụ: góc nhìn 70 độ trên sensor 1920x1080 => f ≈ 1350px)
    """
    def __init__(
        self,
        cam_pos: Tuple[float, float, float] = (3.048, -3.0, 2.2),
        pitch_deg: float = 25.0,
        yaw_deg: float = 0.0,
        roll_deg: float = 0.0,
        focal_px: float = 1350.0,
        image_w: float = 1920.0,
        image_h: float = 1080.0
    ):
        self.cam_pos = cam_pos
        self.pitch = math.radians(pitch_deg)
        self.yaw = math.radians(yaw_deg)
        self.roll = math.radians(roll_deg)
        self.focal = focal_px
        self.cx = image_w / 2.0
        self.cy = image_h / 2.0

        # Ma trận xoay R = R_yaw * R_pitch * R_roll
        # Camera coordinates: X right, Y down, Z forward
        # World coordinates: X right, Y along court length, Z up
        cp, sp = math.cos(self.pitch), math.sin(self.pitch)
        cy, sy = math.cos(self.yaw), math.sin(self.yaw)
        cr, sr = math.cos(self.roll), math.sin(self.roll)

        # Trục thế giới sang trục camera
        # Forward vector ban đầu dọc +Y thế giới, chúc xuống theo pitch (-Z thế giới), quay yaw
        self.R = [
            [cy*cr - sy*sp*sr, -sy*cp, cy*sr + sy*sp*cr],
            [sy*cr + cy*sp*sr,  cy*cp, sy*sr - cy*sp*cr],
            [-cp*sr,           sp,    cp*cr]
        ]

    def project_court_point(self, xw: float, yw: float, zw: float = 0.0) -> Optional[Tuple[float, float]]:
        # Tọa độ tương đối so với camera
        dx = xw - self.cam_pos[0]
        dy = yw - self.cam_pos[1]
        dz = zw - self.cam_pos[2]

        # Biến đổi sang hệ camera:
        # X_cam: ngang
        # Y_cam: dọc xuống
        # Z_cam: chiều sâu (khoảng cách phía trước)
        xc =  dx * math.cos(self.yaw) - dy * math.sin(self.yaw)
        yc_horiz = dx * math.sin(self.yaw) + dy * math.cos(self.yaw)
        
        # Chúc xuống pitch:
        # Trục Z_cam hướng về phía trước sân
        z_cam = yc_horiz * math.cos(self.pitch) + dz * math.sin(self.pitch)
        # Trục Y_cam hướng xuống đất
        y_cam = -yc_horiz * math.sin(self.pitch) + dz * math.cos(self.pitch)
        # Chuyển hệ sang chuẩn camera (Y_cam hướng xuống => lật dấu nếu dz up)
        y_cam_screen = -y_cam # Y pixel tăng dần xuống dưới

        if z_cam <= 0.1: # Sau camera
            return None

        u = self.cx + self.focal * (xc / z_cam)
        v = self.cy + self.focal * (y_cam_screen / z_cam)
        return (u, v)


# ------------------------------------------------------------------------------
# 3. Rule Engine Implementation (Mirroring PickleVision Swift)
# ------------------------------------------------------------------------------

def evaluate_bounce_verdict(
    court_pos: Tuple[float, float],
    is_serve: bool,
    target_service_box: Optional[str] = "farRight"
) -> str:
    x, y = court_pos
    r = BALL_RADIUS

    # 1. Toàn bộ ngoài sân
    if x < -r or x > (COURT_WIDTH + r) or y < -r or y > (COURT_LENGTH + r):
        return "OUT"

    # 2. Giao bóng (Serve)
    if is_serve:
        is_target_far = (y > NET_Y)
        if is_target_far:
            # Sân xa: Vạch bếp nằm ở FAR_NVZ_Y = 8.8392m
            # Chạm vạch bếp (Y <= 8.8392 + r) hoặc rơi trong bếp -> FAULT!
            if y <= (FAR_NVZ_Y + r):
                return "FAULT_KITCHEN_SERVE"
            
            # Ô giao bóng mục tiêu
            if target_service_box == "farRight":
                # Far Right: X in [3.048, 6.096], Y in [8.8392, 13.4112]
                min_x = CENTERLINE_X - r
                max_x = COURT_WIDTH + r
                max_y = COURT_LENGTH + r
                if x >= min_x and x <= max_x and y <= max_y:
                    return "IN"
                else:
                    return "OUT"
            elif target_service_box == "farLeft":
                min_x = -r
                max_x = CENTERLINE_X + r
                max_y = COURT_LENGTH + r
                if x >= min_x and x <= max_x and y <= max_y:
                    return "IN"
                else:
                    return "OUT"
        else:
            # Sân gần: Vạch bếp nằm ở NEAR_NVZ_Y = 4.5720m
            if y >= (NEAR_NVZ_Y - r):
                return "FAULT_KITCHEN_SERVE"
            if target_service_box == "nearRight":
                min_x = CENTERLINE_X - r
                max_x = COURT_WIDTH + r
                min_y = -r
                if x >= min_x and x <= max_x and y >= min_y:
                    return "IN"
                else:
                    return "OUT"
            elif target_service_box == "nearLeft":
                min_x = -r
                max_x = CENTERLINE_X + r
                min_y = -r
                if x >= min_x and x <= max_x and y >= min_y:
                    return "IN"
                else:
                    return "OUT"
        return "IN"

    # 3. Pha bóng sống (Live Rally)
    return "IN"


# ------------------------------------------------------------------------------
# 4. Stress Testing Harness & Execution
# ------------------------------------------------------------------------------

def run_adversarial_challenges():
    print("================================================================================")
    print(" ADVERSARIAL EMPIRICAL VERIFICATION - CHALLENGER 1 (CRITIC & SPECIALIST)")
    print("================================================================================\n")

    ground_truth_corners = [
        (0.0000, 0.0000),             # Near-Left
        (COURT_WIDTH, 0.0000),        # Near-Right
        (COURT_WIDTH, COURT_LENGTH),  # Far-Right
        (0.0000, COURT_LENGTH)        # Far-Left
    ]

    landmarks_11 = [
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

    # Tạo lưới 100 điểm dày đặc trên toàn sân (10 x 10)
    dense_court_grid = []
    for ix in range(10):
        for iy in range(10):
            gx = (ix / 9.0) * COURT_WIDTH
            gy = (iy / 9.0) * COURT_LENGTH
            dense_court_grid.append((gx, gy))

    # --------------------------------------------------------------------------
    # THỬ NGHIỆM 1: DLT HOMOGRAPHY DƯỚI GÓC NGHIÊNG CAMERA MẠNH VÀ NHIỄU SUB-PIXEL
    # --------------------------------------------------------------------------
    print("--------------------------------------------------------------------------------")
    print(" THỬ NGHIỆM 1: THÁCH THỨC DLT HOMOGRAPHY DƯỚI ĐIỀU KIỆN BIÊN")
    print("--------------------------------------------------------------------------------")

    test_cameras = [
        {
            "name": "Standard Baseline Central (H=2.2m, Dist=3.0m, Pitch=20°)",
            "pos": (3.048, -3.0, 2.2),
            "pitch": 20.0,
            "yaw": 0.0
        },
        {
            "name": "Low Tripod Baseline (H=1.8m, Dist=3.0m, Pitch=17°)",
            "pos": (3.048, -3.0, 1.8),
            "pitch": 17.0,
            "yaw": 0.0
        },
        {
            "name": "High Tripod Baseline (H=2.5m, Dist=3.5m, Pitch=22°)",
            "pos": (3.048, -3.5, 2.5),
            "pitch": 22.0,
            "yaw": 0.0
        },
        {
            "name": "Steep Pitch Challenge (H=2.5m, Dist=2.6m, Pitch=25°)",
            "pos": (3.048, -2.6, 2.5),
            "pitch": 25.0,
            "yaw": 0.0
        },
        {
            "name": "Corner Baseline Angled (H=2.2m, X=-1.0m, Y=-3.0m, Pitch=20°, Yaw=12°)",
            "pos": (-1.0, -3.0, 2.2),
            "pitch": 20.0,
            "yaw": 12.0
        }
    ]

    noise_levels = [0.1, 0.2, 0.35, 0.5] # Sub-pixel noise amplitudes (pixels)
    random.seed(42)

    all_dlt_passed = True
    dlt_results_summary = []

    for cam_cfg in test_cameras:
        print(f"\n[Camera Setup] {cam_cfg['name']}:")
        proj = CameraProjector(
            cam_pos=cam_cfg["pos"],
            pitch_deg=cam_cfg["pitch"],
            yaw_deg=cam_cfg["yaw"]
        )

        # Chiếu 4 góc chuẩn sang pixel
        ideal_corners = [proj.project_court_point(p[0], p[1]) for p in ground_truth_corners]
        if any(c is None for c in ideal_corners):
            print("   [ERROR] Camera configuration cannot see all 4 corners!")
            continue

        ideal_landmarks_px = [(name, proj.project_court_point(xw, yw), (xw, yw)) for name, xw, yw in landmarks_11]
        dense_grid_px = [(proj.project_court_point(gx, gy), (gx, gy)) for gx, gy in dense_court_grid]

        for noise_amp in noise_levels:
            # Chạy Monte Carlo 100 lần với nhiễu ngẫu nhiên
            num_trials = 100
            rmse_corners_list = []
            rmse_landmarks_list = []
            rmse_dense_list = []
            max_err_any_point = 0.0

            for _ in range(num_trials):
                noisy_corners = [
                    (c[0] + random.uniform(-noise_amp, noise_amp), c[1] + random.uniform(-noise_amp, noise_amp))
                    for c in ideal_corners
                ]
                solver = DLTHomographySolver(use_hartley=True)
                ok = solver.calibrate(noisy_corners, ground_truth_corners)
                if not ok:
                    continue

                # RMSE 4 góc
                c_pairs = [(noisy_corners[i], ground_truth_corners[i]) for i in range(4)]
                rmse_c = solver.compute_rmse(c_pairs)
                rmse_corners_list.append(rmse_c)

                # RMSE 11 mốc
                l_pairs = [(px, court) for _, px, court in ideal_landmarks_px if px is not None]
                rmse_l = solver.compute_rmse(l_pairs)
                rmse_landmarks_list.append(rmse_l)

                # RMSE trên 100 điểm dày đặc toàn sân
                d_pairs = [(px, court) for px, court in dense_grid_px if px is not None]
                rmse_d = solver.compute_rmse(d_pairs)
                rmse_dense_list.append(rmse_d)

                for px, court in d_pairs:
                    rec = solver.pixel_to_court(px)
                    if rec:
                        err = math.hypot(rec[0] - court[0], rec[1] - court[1])
                        max_err_any_point = max(max_err_any_point, err)

            avg_rmse_c = sum(rmse_corners_list) / len(rmse_corners_list)
            avg_rmse_l = sum(rmse_landmarks_list) / len(rmse_landmarks_list)
            avg_rmse_d = sum(rmse_dense_list) / len(rmse_dense_list)
            max_rmse_d = max(rmse_dense_list)

            status = "PASS (< 0.02m)" if max_rmse_d < 0.02 else "FAIL (>= 0.02m)"
            if max_rmse_d >= 0.02:
                all_dlt_passed = False

            print(f"   * Nhiễu ±{noise_amp:.2f}px: Avg RMSE 4 Corners={avg_rmse_c*1000:.2f}mm | "
                  f"11 Landmarks={avg_rmse_l*1000:.2f}mm | "
                  f"Dense Grid={avg_rmse_d*1000:.2f}mm | "
                  f"Max Grid RMSE={max_rmse_d*1000:.2f}mm | "
                  f"Worst Single Point Err={max_err_any_point*1000:.2f}mm [{status}]")

            dlt_results_summary.append({
                "camera": cam_cfg["name"],
                "noise": noise_amp,
                "avg_grid_rmse": avg_rmse_d,
                "max_grid_rmse": max_rmse_d,
                "passed": (max_rmse_d < 0.02)
            })

    # So sánh có và không có Hartley Normalization
    print("\n[Ablation Test] Kiểm chứng vai trò của Chuẩn hóa Hartley (Hartley vs Non-Hartley):")
    std_proj = CameraProjector(cam_pos=(3.048, -3.0, 2.2), pitch_deg=20.0, yaw_deg=0.0)
    std_corners = [std_proj.project_court_point(p[0], p[1]) for p in ground_truth_corners]
    std_dense_px = [(std_proj.project_court_point(gx, gy), (gx, gy)) for gx, gy in dense_court_grid]

    noisy_c = [
        (std_corners[0][0] + 0.35, std_corners[0][1] - 0.35),
        (std_corners[1][0] - 0.35, std_corners[1][1] + 0.35),
        (std_corners[2][0] + 0.35, std_corners[2][1] - 0.35),
        (std_corners[3][0] - 0.35, std_corners[3][1] + 0.35)
    ]
    solver_hartley = DLTHomographySolver(use_hartley=True)
    solver_hartley.calibrate(noisy_c, ground_truth_corners)
    d_pairs = [(px, court) for px, court in std_dense_px if px is not None]
    rmse_hartley = solver_hartley.compute_rmse(d_pairs)

    solver_no_hartley = DLTHomographySolver(use_hartley=False)
    solver_no_hartley.calibrate(noisy_c, ground_truth_corners)
    rmse_no_hartley = solver_no_hartley.compute_rmse(d_pairs)

    print(f"   - Có Hartley Normalization: Dense Grid RMSE = {rmse_hartley*1000:.3f} mm")
    print(f"   - KHÔNG Hartley Normalization: Dense Grid RMSE = {rmse_no_hartley*1000:.3f} mm")
    if rmse_hartley < rmse_no_hartley:
        print(f"   => Hartley cải thiện độ ổn định số học lên gấp {rmse_no_hartley / (rmse_hartley if rmse_hartley > 0 else 1e-6):.1f} lần!")

    # --------------------------------------------------------------------------
    # THỬ NGHIỆM 2: THÁCH THỨC QUY TẮC IN/OUT LUẬT USA PICKLEBALL
    # --------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print(" THỬ NGHIỆM 2: THÁCH THỨC QUY TẮC IN/OUT LUẬT USA PICKLEBALL")
    print("--------------------------------------------------------------------------------")

    all_rules_passed = True
    rule_results = []

    # 2.1 Quét sát mép vạch bếp sân xa (Far NVZ Line Y = 8.8392m)
    # Mép vạch bếp là Y = 8.8392.
    # Ngưỡng tiếp xúc hình học: Quả bóng chạm vạch nếu tâm Y <= 8.8392 + BALL_RADIUS (8.8762m)
    print("\n[Case 2.1] Quét siêu mịn sát mép Vạch Bếp Sân Xa (Far NVZ: Y = 8.8392m, r = 0.037m):")
    critical_threshold_far = FAR_NVZ_Y + BALL_RADIUS # 8.8762m
    test_y_offsets = [
        -0.0500, # -5cm (Rơi sâu trong bếp)
        -0.0010, # -1mm bên trong vạch bếp (Y = 8.8382m)
        0.0000,  # 0mm (Tâm bóng ngay trên mép ngoài vạch bếp Y = 8.8392m)
        +0.0010, # +1mm ngoài vạch bếp nhưng thân bóng đè lên vạch bếp
        BALL_RADIUS - 0.0010, # 1mm trước ngưỡng thoát tiếp xúc (Y = 8.8752m -> tiếp xúc 1mm)
        BALL_RADIUS,          # Ngưỡng tiếp xúc tiếp tuyến (Y = 8.8762m)
        BALL_RADIUS + 0.0001, # Vừa thoát tiếp xúc 0.1mm (Y = 8.8763m)
        BALL_RADIUS + 0.0010, # Thoát tiếp xúc 1mm (Y = 8.8772m)
        BALL_RADIUS + 0.0100  # Rõ ràng hợp lệ 1cm (Y = 8.8862m)
    ]

    for off in test_y_offsets:
        y_val = FAR_NVZ_Y + off
        # Giao bóng mục tiêu Far Right (X = 4.5m)
        v_serve = evaluate_bounce_verdict((4.5000, y_val), is_serve=True, target_service_box="farRight")
        v_live = evaluate_bounce_verdict((4.5000, y_val), is_serve=False)

        # Kỳ vọng: Nếu y_val <= critical_threshold_far => FAULT_KITCHEN_SERVE, ngược lại => IN
        expected_serve = "FAULT_KITCHEN_SERVE" if y_val <= critical_threshold_far else "IN"
        expected_live = "IN" # Bóng sống rơi trong bếp luôn là IN

        serve_ok = (v_serve == expected_serve)
        live_ok = (v_live == expected_live)
        if not (serve_ok and live_ok):
            all_rules_passed = False

        status_str = "PASS" if (serve_ok and live_ok) else "FAIL"
        print(f"   * Y = {y_val:.5f}m (offset={off*1000:+.1f}mm): "
              f"Serve={v_serve} (Exp: {expected_serve}) | "
              f"Live={v_live} (Exp: {expected_live}) [{status_str}]")

    # 2.2 Thử nghiệm tọa độ quy chiếu từ Lưới (NVZ Length = 2.1336 ± 0.001m):
    print("\n[Case 2.2] Kiểm chứng khoảng cách tính từ Lưới (2.1336m ± 0.001m):")
    # Khoảng cách 2.1336m chính là chiều dài khu vực bếp từ lưới
    # Khi tính từ tâm lưới Y_net = 6.7056:
    # Y = 6.7056 + 2.1336 = 8.8392m (Vạch bếp xa)
    # Y = 6.7056 - 2.1336 = 4.5720m (Vạch bếp gần)
    for delta_mm in [-1.0, 0.0, +1.0]:
        dist = NVZ_LENGTH + (delta_mm / 1000.0)
        y_far = NET_Y + dist
        v_serve = evaluate_bounce_verdict((4.5000, y_far), is_serve=True, target_service_box="farRight")
        # Tâm bóng ở 2.1336m + delta_mm => Đều <= 2.1336 + 0.037m => 100% PHẢI LÀ FAULT!
        assert_fault = (v_serve == "FAULT_KITCHEN_SERVE")
        print(f"   * Khoảng cách từ Lưới = {dist:.4f}m ({delta_mm:+.1f}mm): Serve Verdict = {v_serve} (FAULT 100%: {assert_fault})")
        if not assert_fault:
            all_rules_passed = False

    # 2.3 Quét sát mép vạch bếp sân gần (Near NVZ Line Y = 4.5720m)
    print("\n[Case 2.3] Quét siêu mịn sát mép Vạch Bếp Sân Gần (Near NVZ: Y = 4.5720m):")
    critical_threshold_near = NEAR_NVZ_Y - BALL_RADIUS # 4.5350m
    near_offsets = [-BALL_RADIUS - 0.001, -BALL_RADIUS, -BALL_RADIUS + 0.001, 0.0, +0.05]
    for off in near_offsets:
        y_val = NEAR_NVZ_Y + off
        v_serve = evaluate_bounce_verdict((1.5000, y_val), is_serve=True, target_service_box="nearLeft")
        v_live = evaluate_bounce_verdict((1.5000, y_val), is_serve=False)
        expected_serve = "FAULT_KITCHEN_SERVE" if y_val >= critical_threshold_near else "IN"
        expected_live = "IN"
        print(f"   * Y = {y_val:.5f}m (offset={off*1000:+.1f}mm): Serve={v_serve} (Exp: {expected_serve}) | Live={v_live}")
        if v_serve != expected_serve or v_live != expected_live:
            all_rules_passed = False

    # 2.4 Kiểm tra các vạch biên khác (Sidelines, Baselines, Centerline)
    print("\n[Case 2.4] Kiểm tra các vạch biên & đường phân cách (In/Out Boundaries):")
    boundary_cases = [
        ("Baseline Touch (Y = 13.4112m)", (4.5000, COURT_LENGTH), True, "farRight", "IN"),
        ("Baseline Grazing Outside (Y = 13.4112 + 0.036m)", (4.5000, COURT_LENGTH + 0.036), True, "farRight", "IN"),
        ("Baseline Full Out (Y = 13.4112 + 0.038m)", (4.5000, COURT_LENGTH + 0.038), True, "farRight", "OUT"),
        ("Right Sideline Touch (X = 6.0960m)", (COURT_WIDTH, 10.5000), True, "farRight", "IN"),
        ("Right Sideline Grazing Outside (X = 6.0960 + 0.036m)", (COURT_WIDTH + 0.036, 10.5000), True, "farRight", "IN"),
        ("Right Sideline Full Out (X = 6.0960 + 0.038m)", (COURT_WIDTH + 0.038, 10.5000), True, "farRight", "OUT"),
        ("Centerline Touch (X = 3.0480m)", (CENTERLINE_X, 10.5000), True, "farRight", "IN"),
        ("Centerline Grazing Left Box (X = 3.0480 - 0.036m)", (CENTERLINE_X - 0.036, 10.5000), True, "farRight", "IN"),
        ("Wrong Service Box Out (X = 3.0480 - 0.038m)", (CENTERLINE_X - 0.038, 10.5000), True, "farRight", "OUT"),
    ]

    for desc, pos, is_srv, box, exp in boundary_cases:
        v = evaluate_bounce_verdict(pos, is_serve=is_srv, target_service_box=box)
        ok = (v == exp)
        if not ok:
            all_rules_passed = False
        print(f"   * {desc:<50}: Verdict={v:<5} (Expected: {exp:<5}) [{'PASS' if ok else 'FAIL'}]")

    # --------------------------------------------------------------------------
    # TỔNG KẾT VÀ PHÁN QUYẾT
    # --------------------------------------------------------------------------
    print("\n================================================================================")
    print(" TỔNG HỢP KẾT QUẢ ĐỐI KHÁNG THỰC NGHIỆM")
    print("================================================================================")
    print(f"1. DLT Homography SVD (<0.02m qua 5 góc camera nghiêng & nhiễu 0.1-0.5px): {'VƯỢT QUA (PASS)' if all_dlt_passed else 'THẤT BẠI (FAIL)'}")
    print(f"2. USA Pickleball In/Out Rule Engine (Vạch bếp FAULT 100%, Bóng sống IN):    {'VƯỢT QUA (PASS)' if all_rules_passed else 'THẤT BẠI (FAIL)'}")
    
    final_verdict = "APPROVE" if (all_dlt_passed and all_rules_passed) else "REQUEST_CHANGES"
    print(f"\n=> PHÁN QUYẾT CUỐI CÙNG: {final_verdict}")
    print("================================================================================")
    return final_verdict, all_dlt_passed, all_rules_passed

if __name__ == "__main__":
    verdict, dlt_ok, rules_ok = run_adversarial_challenges()
    sys.exit(0 if verdict == "APPROVE" else 1)
