//
//  CourtMiniMapView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Accurate 2D Top-Down Minimap adhering strictly to USA Pickleball Dimensions.
//

import SwiftUI

/// Dữ liệu phục vụ hiển thị trên Minimap 2D
public struct CourtMinimapData: Equatable {
    public var playerPositions: [Int: CGPoint] = [:]       // Tọa độ mét (X: 0..6.096, Y: 0..13.4112)
    public var playerTrails: [Int: [CGPoint]] = [:]         // Lịch sử tọa độ mét
    public var ballPositionCourt: CGPoint? = nil           // Vị trí bóng tức thời
    public var ballTrajectoryCourt: [CGPoint] = []         // Quỹ đạo bóng mét
    public var lastBounceCourt: CGPoint? = nil             // Điểm nảy gần nhất
    public var lastBounceVerdict: InOutVerdict? = nil      // Phán quyết IN / OUT / FAULT
    
    public init(
        playerPositions: [Int: CGPoint] = [:],
        playerTrails: [Int: [CGPoint]] = [:],
        ballPositionCourt: CGPoint? = nil,
        ballTrajectoryCourt: [CGPoint] = [],
        lastBounceCourt: CGPoint? = nil,
        lastBounceVerdict: InOutVerdict? = nil
    ) {
        self.playerPositions = playerPositions
        self.playerTrails = playerTrails
        self.ballPositionCourt = ballPositionCourt
        self.ballTrajectoryCourt = ballTrajectoryCourt
        self.lastBounceCourt = lastBounceCourt
        self.lastBounceVerdict = lastBounceVerdict
    }
}

/// Bản đồ 2D nhìn từ trên cao đặt ở cột phải (chuẩn kích thước 170x260 pt)
public struct CourtMiniMapView: View {
    
    // MARK: - Properties
    
    public let data: CourtMinimapData
    
    // MARK: - USA Pickleball Court Geometric Constants (Meters)
    
    private let courtWidthM: CGFloat = CGFloat(CourtDimensions.width)        // 6.0960 m
    private let courtLengthM: CGFloat = CGFloat(CourtDimensions.length)      // 13.4112 m
    private let nearNVZYM: CGFloat = CGFloat(CourtDimensions.nearNVZY)        // 4.5720 m
    private let farNVZYM: CGFloat = CGFloat(CourtDimensions.farNVZY)          // 8.8392 m
    private let netYM: CGFloat = CGFloat(CourtDimensions.netY)                // 6.7056 m
    private let centerLineXM: CGFloat = CGFloat(CourtDimensions.centerLineX)  // 3.0480 m
    
    public init(data: CourtMinimapData) {
        self.data = data
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 4) {
            // Header tiêu đề Minimap
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                Text("2D MINIMAP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("USA-PB 13.4m")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            // Khung vẽ sân 2D Canvas
            Canvas { context, size in
                let margin: CGFloat = 6.0
                let drawWidth = size.width - margin * 2
                let drawHeight = size.height - margin * 2
                
                let scaleX = drawWidth / courtWidthM
                let scaleY = drawHeight / courtLengthM
                
                // Hàm chuyển đổi từ tọa độ Mét sang Pixel trên Canvas
                // Lưu ý: Y=0 là Baseline sân gần (đáy màn hình) nên ta đảo trục Y để trực quan theo góc nhìn camera
                func courtToScreen(_ pt: CGPoint) -> CGPoint {
                    let px = margin + pt.x * scaleX
                    let py = margin + (courtLengthM - pt.y) * scaleY
                    return CGPoint(x: px, y: py)
                }
                
                // 1. Vẽ nền sân chính (Ngoại vi và 2 ô giao bóng: Xanh Dương Đậm)
                let courtOrigin = courtToScreen(CGPoint(x: 0, y: courtLengthM))
                let courtRect = CGRect(x: courtOrigin.x, y: courtOrigin.y, width: drawWidth, height: drawHeight)
                let courtPath = Path(roundedRect: courtRect, cornerRadius: 4)
                context.fill(courtPath, with: .color(Color(red: 0.12, green: 0.28, blue: 0.44)))
                
                // 2. Vẽ khu vực Bếp NVZ (Non-Volley Zone: Xanh Ngọc / Emerald Green)
                let nvzTop = courtToScreen(CGPoint(x: 0, y: farNVZYM))
                let nvzBottom = courtToScreen(CGPoint(x: courtWidthM, y: nearNVZYM))
                let nvzHeight = abs(nvzBottom.y - nvzTop.y)
                let nvzRect = CGRect(x: margin, y: nvzTop.y, width: drawWidth, height: nvzHeight)
                context.fill(Path(nvzRect), with: .color(Color(red: 0.16, green: 0.48, blue: 0.38)))
                
                // 3. Vẽ các đường vạch sơn trắng chuẩn USA Pickleball
                var linesPath = Path()
                
                // Viền ngoài (Baselines & Sidelines)
                linesPath.addRect(courtRect)
                
                // 2 Vạch Bếp (NVZ Lines)
                let nearNVZScreenY = courtToScreen(CGPoint(x: 0, y: nearNVZYM)).y
                linesPath.move(to: CGPoint(x: margin, y: nearNVZScreenY))
                linesPath.addLine(to: CGPoint(x: margin + drawWidth, y: nearNVZScreenY))
                
                let farNVZScreenY = courtToScreen(CGPoint(x: 0, y: farNVZYM)).y
                linesPath.move(to: CGPoint(x: margin, y: farNVZScreenY))
                linesPath.addLine(to: CGPoint(x: margin + drawWidth, y: farNVZScreenY))
                
                // Vạch giữa sân (Centerlines) chia 2 ô giao bóng
                let centerLineScreenX = courtToScreen(CGPoint(x: centerLineXM, y: 0)).x
                // Nửa sân gần: từ vạch đáy đến vạch bếp gần
                let nearBaselineY = courtToScreen(CGPoint(x: 0, y: 0)).y
                linesPath.move(to: CGPoint(x: centerLineScreenX, y: nearBaselineY))
                linesPath.addLine(to: CGPoint(x: centerLineScreenX, y: nearNVZScreenY))
                // Nửa sân xa: từ vạch bếp xa đến vạch đáy xa
                let farBaselineY = courtToScreen(CGPoint(x: 0, y: courtLengthM)).y
                linesPath.move(to: CGPoint(x: centerLineScreenX, y: farNVZScreenY))
                linesPath.addLine(to: CGPoint(x: centerLineScreenX, y: farBaselineY))
                
                context.stroke(linesPath, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
                
                // 4. Vẽ lưới trung tâm (Center Net) - nét đứt mỏng
                let netScreenY = courtToScreen(CGPoint(x: 0, y: netYM)).y
                var netPath = Path()
                netPath.move(to: CGPoint(x: margin - 3, y: netScreenY))
                netPath.addLine(to: CGPoint(x: margin + drawWidth + 3, y: netScreenY))
                context.stroke(
                    netPath,
                    with: .color(Color(white: 0.95)),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [4, 3])
                )
                
                // 5. Vẽ vệt di chuyển (Trails) của 4 cầu thủ
                for (playerIdx, trail) in data.playerTrails {
                    guard trail.count > 1 else { continue }
                    var trailPath = Path()
                    trailPath.move(to: courtToScreen(trail[0]))
                    for pt in trail.dropFirst() {
                        trailPath.addLine(to: courtToScreen(pt))
                    }
                    let playerColor = colorForPlayer(playerIdx)
                    context.stroke(trailPath, with: .color(playerColor.opacity(0.35)), lineWidth: 2.2)
                }
                
                // 6. Vẽ vị trí 4 cầu thủ
                for (playerIdx, posM) in data.playerPositions {
                    let center = courtToScreen(posM)
                    let pColor = colorForPlayer(playerIdx)
                    
                    // Vòng hào quang phát sáng
                    let haloRect = CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)
                    context.fill(Path(ellipseIn: haloRect), with: .color(pColor.opacity(0.28)))
                    
                    // Chấm tròn tâm
                    let dotRect = CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9)
                    context.fill(Path(ellipseIn: dotRect), with: .color(pColor))
                    context.stroke(Path(ellipseIn: dotRect), with: .color(.white), lineWidth: 1.0)
                }
                
                // 7. Vẽ đường bay của bóng (Ball Trajectory Trail)
                if data.ballTrajectoryCourt.count > 1 {
                    var ballPath = Path()
                    ballPath.move(to: courtToScreen(data.ballTrajectoryCourt[0]))
                    for pt in data.ballTrajectoryCourt.dropFirst() {
                        ballPath.addLine(to: courtToScreen(pt))
                    }
                    context.stroke(ballPath, with: .color(.yellow.opacity(0.85)), lineWidth: 1.8)
                }
                
                // 8. Vẽ vị trí bóng tức thời
                if let ballPosM = data.ballPositionCourt {
                    let ballScreen = courtToScreen(ballPosM)
                    let ballDot = CGRect(x: ballScreen.x - 3.5, y: ballScreen.y - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: ballDot), with: .color(.yellow))
                    context.stroke(Path(ellipseIn: ballDot), with: .color(.black.opacity(0.4)), lineWidth: 0.8)
                }
                
                // 9. Vẽ điểm nảy (Bounce Marker) kèm phán quyết
                if let bounceM = data.lastBounceCourt {
                    let bounceScreen = courtToScreen(bounceM)
                    let isFault = (data.lastBounceVerdict?.isFaultOrOut == true)
                    let badgeColor: Color = isFault ? Color(red: 0.95, green: 0.22, blue: 0.22) : Color(red: 0.15, green: 0.88, blue: 0.45)
                    
                    // Vòng tròn gợn sóng
                    let rippleRect = CGRect(x: bounceScreen.x - 8, y: bounceScreen.y - 8, width: 16, height: 16)
                    context.stroke(Path(ellipseIn: rippleRect), with: .color(badgeColor), lineWidth: 1.5)
                    
                    // Tâm điểm nảy
                    let centerDot = CGRect(x: bounceScreen.x - 3.5, y: bounceScreen.y - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: centerDot), with: .color(badgeColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Footer nhãn phán quyết điểm nảy gần nhất
            if let bounce = data.lastBounceCourt, let verdict = data.lastBounceVerdict {
                HStack(spacing: 4) {
                    Circle()
                        .fill(verdict.isFaultOrOut ? Color.red : Color.green)
                        .frame(width: 6, height: 6)
                    Text(verdict.rawValue)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(verdict.isFaultOrOut ? .red : .green)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "(%.1f, %.1f)m", bounce.x, bounce.y))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
        .frame(width: 140, height: 210)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Color Palette for 4 Players
    
    private func colorForPlayer(_ index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.22, green: 0.52, blue: 0.98) // Tú (Đội Gần Trái: Xanh Dương)
        case 1: return Color(red: 0.58, green: 0.38, blue: 0.98) // Cường (Đội Gần Phải: Tím)
        case 2: return Color(red: 0.98, green: 0.46, blue: 0.12) // Nam (Đội Xa Trái: Cam)
        case 3: return Color(red: 0.94, green: 0.28, blue: 0.28) // Thành (Đội Xa Phải: Đỏ)
        default: return .white
        }
    }
}
