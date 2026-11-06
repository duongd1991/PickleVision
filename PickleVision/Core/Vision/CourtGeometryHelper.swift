//
//  CourtGeometryHelper.swift
//  PickleVision
//
//  Created by Backend Coder on 2026-11-06.
//  Geometric boundary constraints for 10-point court calibration.
//  Kitchen and net points are constrained to slide strictly along the sidelines.
//

import CoreGraphics

public enum CourtGeometryHelper {
    
    /// Tính tham số chiếu vuông góc t của điểm M lên đoạn thẳng A -> B: M' = A + t * (B - A)
    public static func computeT(point: CGPoint, segA: CGPoint, segB: CGPoint) -> CGFloat {
        let dx = segB.x - segA.x
        let dy = segB.y - segA.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 1e-6 else { return 0.5 }
        let t = ((point.x - segA.x) * dx + (point.y - segA.y) * dy) / lengthSq
        return min(max(t, 0.01), 0.99)
    }
    
    /// Chiếu điểm M lên đoạn thẳng A -> B với khoảng kẹp [tMin, tMax]
    public static func projectPoint(point: CGPoint, segA: CGPoint, segB: CGPoint, tMin: CGFloat, tMax: CGFloat) -> CGPoint {
        let dx = segB.x - segA.x
        let dy = segB.y - segA.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 1e-6 else { return segA }
        let t = ((point.x - segA.x) * dx + (point.y - segA.y) * dy) / lengthSq
        let clampedT = min(max(t, tMin), tMax)
        return CGPoint(x: segA.x + clampedT * dx, y: segA.y + clampedT * dy)
    }
    
    /// Cập nhật vị trí chốt index khi kéo, áp dụng ràng buộc trượt trên đường biên
    /// 10 mốc chuẩn:
    /// - 0: Đáy Gần Trái (P0), 1: Đáy Gần Phải (P1)
    /// - 2: Đáy Xa Phải (P2), 3: Đáy Xa Trái (P3)
    /// - 4: Bếp Gần Trái (P4), 5: Bếp Gần Phải (P5)
    /// - 6: Bếp Xa Phải (P6), 7: Bếp Xa Trái (P7)
    /// - 8: Cột Lưới Trái (P8), 9: Cột Lưới Phải (P9)
    public static func updateCorner(corners: inout [CGPoint], index: Int, rawTouch: CGPoint) {
        guard corners.count >= 10 else {
            if index < corners.count {
                corners[index] = rawTouch
            }
            return
        }
        
        let clampedTouch = CGPoint(
            x: min(max(rawTouch.x, 0.0), 1.0),
            y: min(max(rawTouch.y, 0.0), 1.0)
        )
        
        switch index {
        case 0:
            // Kéo Đáy Gần Trái P0 -> Tính lại P4, P8, P7 trên biên trái P0 -> P3
            let t4 = computeT(point: corners[4], segA: corners[0], segB: corners[3])
            let t8 = computeT(point: corners[8], segA: corners[0], segB: corners[3])
            let t7 = computeT(point: corners[7], segA: corners[0], segB: corners[3])
            corners[0] = clampedTouch
            let dx = corners[3].x - corners[0].x
            let dy = corners[3].y - corners[0].y
            corners[4] = CGPoint(x: corners[0].x + t4 * dx, y: corners[0].y + t4 * dy)
            corners[8] = CGPoint(x: corners[0].x + t8 * dx, y: corners[0].y + t8 * dy)
            corners[7] = CGPoint(x: corners[0].x + t7 * dx, y: corners[0].y + t7 * dy)
            
        case 3:
            // Kéo Đáy Xa Trái P3 -> Tính lại P4, P8, P7 trên biên trái P0 -> P3
            let t4 = computeT(point: corners[4], segA: corners[0], segB: corners[3])
            let t8 = computeT(point: corners[8], segA: corners[0], segB: corners[3])
            let t7 = computeT(point: corners[7], segA: corners[0], segB: corners[3])
            corners[3] = clampedTouch
            let dx = corners[3].x - corners[0].x
            let dy = corners[3].y - corners[0].y
            corners[4] = CGPoint(x: corners[0].x + t4 * dx, y: corners[0].y + t4 * dy)
            corners[8] = CGPoint(x: corners[0].x + t8 * dx, y: corners[0].y + t8 * dy)
            corners[7] = CGPoint(x: corners[0].x + t7 * dx, y: corners[0].y + t7 * dy)
            
        case 1:
            // Kéo Đáy Gần Phải P1 -> Tính lại P5, P9, P6 trên biên phải P1 -> P2
            let t5 = computeT(point: corners[5], segA: corners[1], segB: corners[2])
            let t9 = computeT(point: corners[9], segA: corners[1], segB: corners[2])
            let t6 = computeT(point: corners[6], segA: corners[1], segB: corners[2])
            corners[1] = clampedTouch
            let dx = corners[2].x - corners[1].x
            let dy = corners[2].y - corners[1].y
            corners[5] = CGPoint(x: corners[1].x + t5 * dx, y: corners[1].y + t5 * dy)
            corners[9] = CGPoint(x: corners[1].x + t9 * dx, y: corners[1].y + t9 * dy)
            corners[6] = CGPoint(x: corners[1].x + t6 * dx, y: corners[1].y + t6 * dy)
            
        case 2:
            // Kéo Đáy Xa Phải P2 -> Tính lại P5, P9, P6 trên biên phải P1 -> P2
            let t5 = computeT(point: corners[5], segA: corners[1], segB: corners[2])
            let t9 = computeT(point: corners[9], segA: corners[1], segB: corners[2])
            let t6 = computeT(point: corners[6], segA: corners[1], segB: corners[2])
            corners[2] = clampedTouch
            let dx = corners[2].x - corners[1].x
            let dy = corners[2].y - corners[1].y
            corners[5] = CGPoint(x: corners[1].x + t5 * dx, y: corners[1].y + t5 * dy)
            corners[9] = CGPoint(x: corners[1].x + t9 * dx, y: corners[1].y + t9 * dy)
            corners[6] = CGPoint(x: corners[1].x + t6 * dx, y: corners[1].y + t6 * dy)
            
        case 4:
            // Bếp Gần Trái: Trượt trên P0 -> P3, kẹp giữa P0 và Lưới Trái P8
            let t8 = computeT(point: corners[8], segA: corners[0], segB: corners[3])
            corners[4] = projectPoint(point: clampedTouch, segA: corners[0], segB: corners[3], tMin: 0.05, tMax: max(0.06, t8 - 0.03))
            
        case 8:
            // Cột Lưới Trái: Trượt trên P0 -> P3, kẹp giữa Bếp Gần P4 và Bếp Xa P7
            let t4 = computeT(point: corners[4], segA: corners[0], segB: corners[3])
            let t7 = computeT(point: corners[7], segA: corners[0], segB: corners[3])
            corners[8] = projectPoint(point: clampedTouch, segA: corners[0], segB: corners[3], tMin: min(t4 + 0.03, 0.94), tMax: max(0.06, t7 - 0.03))
            
        case 7:
            // Bếp Xa Trái: Trượt trên P0 -> P3, kẹp giữa Lưới Trái P8 và Đáy Xa P3
            let t8 = computeT(point: corners[8], segA: corners[0], segB: corners[3])
            corners[7] = projectPoint(point: clampedTouch, segA: corners[0], segB: corners[3], tMin: min(t8 + 0.03, 0.94), tMax: 0.95)
            
        case 5:
            // Bếp Gần Phải: Trượt trên P1 -> P2, kẹp giữa P1 và Lưới Phải P9
            let t9 = computeT(point: corners[9], segA: corners[1], segB: corners[2])
            corners[5] = projectPoint(point: clampedTouch, segA: corners[1], segB: corners[2], tMin: 0.05, tMax: max(0.06, t9 - 0.03))
            
        case 9:
            // Cột Lưới Phải: Trượt trên P1 -> P2, kẹp giữa Bếp Gần P5 và Bếp Xa P6
            let t5 = computeT(point: corners[5], segA: corners[1], segB: corners[2])
            let t6 = computeT(point: corners[6], segA: corners[1], segB: corners[2])
            corners[9] = projectPoint(point: clampedTouch, segA: corners[1], segB: corners[2], tMin: min(t5 + 0.03, 0.94), tMax: max(0.06, t6 - 0.03))
            
        case 6:
            // Bếp Xa Phải: Trượt trên P1 -> P2, kẹp giữa Lưới Phải P9 và Đáy Xa P2
            let t9 = computeT(point: corners[9], segA: corners[1], segB: corners[2])
            corners[6] = projectPoint(point: clampedTouch, segA: corners[1], segB: corners[2], tMin: min(t9 + 0.03, 0.94), tMax: 0.95)
            
        default:
            corners[index] = clampedTouch
        }
    }
}
