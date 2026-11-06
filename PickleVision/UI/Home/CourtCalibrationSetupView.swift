//
//  CourtCalibrationSetupView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-06.
//  Step 2: Fullscreen Clean Court ROI Calibration Setup Screen without UI Bars.
//  Direct Touch & Drag Gestures for 10 Landmark Points (4 Corners + 4 Kitchen + 2 Net).
//

import SwiftUI
import CoreVideo

/// Màn hình căn chỉnh ROI 10 điểm sân thi đấu trước khi vào trận chính
public struct CourtCalibrationSetupView: View {
    
    // MARK: - Default 10 Landmark Points (Normalized [0...1])
    public static let default10Points: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.88),      // 0: Đáy Gần Trái (P0)
        CGPoint(x: 0.88, y: 0.88),      // 1: Đáy Gần Phải (P1)
        CGPoint(x: 0.68, y: 0.22),      // 2: Đáy Xa Phải (P2)
        CGPoint(x: 0.32, y: 0.22),      // 3: Đáy Xa Trái (P3)
        CGPoint(x: 0.1882, y: 0.6550),  // 4: Bếp Gần Trái (P4)
        CGPoint(x: 0.8118, y: 0.6550),  // 5: Bếp Gần Phải (P5)
        CGPoint(x: 0.7482, y: 0.4450),  // 6: Bếp Xa Phải (P6)
        CGPoint(x: 0.2518, y: 0.4450),  // 7: Bếp Xa Trái (P7)
        CGPoint(x: 0.2200, y: 0.5500),  // 8: Chân Lưới Trái (P8)
        CGPoint(x: 0.7800, y: 0.5500)   // 9: Chân Lưới Phải (P9)
    ]
    
    // MARK: - Properties & Callbacks
    
    @Binding public var currentFrameBuffer: CVPixelBuffer?
    public var initialCorners: [CGPoint]
    public var onBack: () -> Void
    public var onNext: (_ calibratedCorners: [CGPoint]) -> Void
    
    // MARK: - Local States
    
    @State private var calibrationCorners: [CGPoint]
    @State private var interactionMode: CameraPreviewInteractionMode = .courtCalibration(selectedCornerIndex: 0)
    @State private var activeDraggingIndex: Int? = nil
    
    public init(
        currentFrameBuffer: Binding<CVPixelBuffer?>,
        initialCorners: [CGPoint] = CourtCalibrationSetupView.default10Points,
        onBack: @escaping () -> Void,
        onNext: @escaping (_ calibratedCorners: [CGPoint]) -> Void
    ) {
        self._currentFrameBuffer = currentFrameBuffer
        self.initialCorners = initialCorners.count >= 10 ? initialCorners : CourtCalibrationSetupView.default10Points
        self._calibrationCorners = State(initialValue: self.initialCorners)
        self.onBack = onBack
        self.onNext = onNext
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Toàn cảnh Camera Feed qua Metal (Không bị kéo giãn)
                CameraPreviewView(
                    pixelBuffer: $currentFrameBuffer,
                    interactionMode: $interactionMode,
                    calibrationCorners: $calibrationCorners,
                    onCalibrationCompleted: { updated in
                        self.calibrationCorners = updated
                    }
                )
                .ignoresSafeArea()
                
                // 2. Lớp Đa Giác ROI 10 Điểm Sân & Chốt Kéo Thả Trực Tiếp Bằng Tay
                CalibrationROIOverlay(
                    corners: $calibrationCorners,
                    viewSize: geometry.size,
                    activeDraggingIndex: $activeDraggingIndex
                )
                .coordinateSpace(name: "CourtCalibrationSetupArea")
                
                // 3. Thanh Tiêu Đề Điều Hướng Nằm Gọn Ở Mép Trên (Không che khuất sân)
                VStack {
                    HStack(spacing: 12) {
                        // Nút Quay lại Bước 1
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Cầu Thủ")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        // Hướng dẫn thao tác
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12, weight: .bold))
                                Text("CHẠM & KÉO THẢ 10 ĐIỂM SÂN BẰNG TAY")
                                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            Text("Chạm vào từng chốt để di chuyển: Vàng (4 Góc), Cam (4 Bếp), Xanh ngọc (2 Lưới)")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // Nút Đặt lại vị trí mặc định
                        Button(action: resetToDefault) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("MẶC ĐỊNH")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        // Nút TIẾP TỤC (Vào trận đấu)
                        Button(action: {
                            onNext(calibrationCorners)
                        }) {
                            HStack(spacing: 5) {
                                Text("TIẾP TỤC")
                                    .font(.system(size: 12, weight: .black))
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color.green.opacity(0.4), radius: 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
        }
    }
    
    private func resetToDefault() {
        calibrationCorners = CourtCalibrationSetupView.default10Points
    }
}

// MARK: - Subview: Lớp Vẽ Đa Giác ROI 10 Điểm & Chốt Kéo Thả Trực Tiếp

private struct CalibrationROIOverlay: View {
    @Binding var corners: [CGPoint]
    let viewSize: CGSize
    @Binding var activeDraggingIndex: Int?
    
    private let landmarkNames = [
        "1. Đáy Gần Trái",
        "2. Đáy Gần Phải",
        "3. Đáy Xa Phải",
        "4. Đáy Xa Trái",
        "5. Bếp Gần Trái",
        "6. Bếp Gần Phải",
        "7. Bếp Xa Phải",
        "8. Bếp Xa Trái",
        "9. Cột Lưới Trái",
        "10. Cột Lưới Phải"
    ]
    
    var body: some View {
        ZStack {
            // 1. LỚP CANVAS ĐỒ HỌA SÂN (Cho phép touch xuyên qua bằng allowsHitTesting: false)
            Canvas { context, size in
                let pts = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                
                // Viền sân ngoài (Corners 0 -> 1 -> 2 -> 3 -> 0)
                if pts.count >= 4 {
                    var outerPath = Path()
                    outerPath.move(to: pts[0])
                    outerPath.addLine(to: pts[1])
                    outerPath.addLine(to: pts[2])
                    outerPath.addLine(to: pts[3])
                    outerPath.closeSubpath()
                    
                    context.fill(outerPath, with: .color(Color.blue.opacity(0.12)))
                    context.stroke(outerPath, with: .color(Color.cyan), lineWidth: 2.5)
                }
                
                // Vùng Bếp Non-Volley Zone (Kitchen: 4 -> 5 -> 6 -> 7)
                if pts.count >= 8 {
                    var kitchenPath = Path()
                    kitchenPath.move(to: pts[4])
                    kitchenPath.addLine(to: pts[5])
                    kitchenPath.addLine(to: pts[6])
                    kitchenPath.addLine(to: pts[7])
                    kitchenPath.closeSubpath()
                    
                    context.fill(kitchenPath, with: .color(Color.orange.opacity(0.18)))
                    
                    // Vạch Bếp Gần (4 -> 5)
                    var nearKitchenLine = Path()
                    nearKitchenLine.move(to: pts[4])
                    nearKitchenLine.addLine(to: pts[5])
                    context.stroke(nearKitchenLine, with: .color(Color.orange), lineWidth: 2.4)
                    
                    // Vạch Bếp Xa (7 -> 6)
                    var farKitchenLine = Path()
                    farKitchenLine.move(to: pts[7])
                    farKitchenLine.addLine(to: pts[6])
                    context.stroke(farKitchenLine, with: .color(Color.orange), lineWidth: 2.4)
                }
                
                // Đường Mép Lưới (Net: 8 -> 9)
                if pts.count >= 10 {
                    var netPath = Path()
                    netPath.move(to: pts[8])
                    netPath.addLine(to: pts[9])
                    context.stroke(
                        netPath,
                        with: .color(Color.white),
                        style: StrokeStyle(lineWidth: 2.2, dash: [6, 4])
                    )
                }
                
                // Đường Phân Chia Ô Phát Bóng (Centerlines)
                if pts.count >= 8 {
                    let midNearBL = CGPoint(x: (pts[0].x + pts[1].x) / 2.0, y: (pts[0].y + pts[1].y) / 2.0)
                    let midNearNVZ = CGPoint(x: (pts[4].x + pts[5].x) / 2.0, y: (pts[4].y + pts[5].y) / 2.0)
                    var nearCenterPath = Path()
                    nearCenterPath.move(to: midNearBL)
                    nearCenterPath.addLine(to: midNearNVZ)
                    context.stroke(nearCenterPath, with: .color(Color.cyan.opacity(0.7)), lineWidth: 1.5)
                    
                    let midFarBL = CGPoint(x: (pts[3].x + pts[2].x) / 2.0, y: (pts[3].y + pts[2].y) / 2.0)
                    let midFarNVZ = CGPoint(x: (pts[7].x + pts[6].x) / 2.0, y: (pts[7].y + pts[6].y) / 2.0)
                    var farCenterPath = Path()
                    farCenterPath.move(to: midFarBL)
                    farCenterPath.addLine(to: midFarNVZ)
                    context.stroke(farCenterPath, with: .color(Color.cyan.opacity(0.7)), lineWidth: 1.5)
                }
            }
            .allowsHitTesting(false) // QUAN TRỌNG: Không chặn sự kiện chạm của các chốt ghim!
            
            // 2. VÙNG CẢM ỨNG NỀN TỔNG QUÁT: Chạm & Kéo chốt gần nhất
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named("CourtCalibrationSetupArea"))
                        .onChanged { value in
                            guard viewSize.width > 0 && viewSize.height > 0 else { return }
                            let touchNorm = CGPoint(
                                x: value.location.x / viewSize.width,
                                y: value.location.y / viewSize.height
                            )
                            
                            // Nếu chưa xác định chốt kéo, tìm chốt gần nhất trong bán kính 65pt
                            if activeDraggingIndex == nil {
                                var bestIdx: Int? = nil
                                var minDist: CGFloat = 0.12 // ~12% màn hình
                                for i in 0..<corners.count {
                                    let d = hypot(corners[i].x - touchNorm.x, corners[i].y - touchNorm.y)
                                    if d < minDist {
                                        minDist = d
                                        bestIdx = i
                                    }
                                }
                                activeDraggingIndex = bestIdx
                            }
                            
                            if let idx = activeDraggingIndex, idx < corners.count {
                                CourtGeometryHelper.updateCorner(corners: &corners, index: idx, rawTouch: touchNorm)
                            }
                        }
                        .onEnded { _ in
                            activeDraggingIndex = nil
                        }
                )
            
            // 3. 10 CHỐT GHIM CÓ THỂ KÉO THẢ TRỰC TIẾP (DIRECT DRAG GESTURE)
            ForEach(0..<corners.count, id: \.self) { i in
                let corner = corners[i]
                let px = corner.x * viewSize.width
                let py = corner.y * viewSize.height
                let isDragging = (activeDraggingIndex == i)
                let color = colorForLandmark(i)
                
                VStack(spacing: 3) {
                    Circle()
                        .fill(isDragging ? Color.white : color)
                        .frame(width: isDragging ? 26 : 20, height: isDragging ? 26 : 20)
                        .overlay(
                            Circle()
                                .stroke(isDragging ? Color.yellow : Color.white, lineWidth: isDragging ? 3.0 : 2.0)
                        )
                        .shadow(color: (isDragging ? Color.yellow : color).opacity(0.95), radius: isDragging ? 10 : 6)
                        .scaleEffect(isDragging ? 1.25 : 1.0)
                    
                    Text(landmarkNames[min(i, landmarkNames.count - 1)])
                        .font(.system(size: 8.5, weight: .black))
                        .foregroundColor(isDragging ? .yellow : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isDragging ? Color.yellow : Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                // Vùng chạm rộng 56x56 pt để ngón tay chạm cực nhạy
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
                .position(x: px, y: py)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("CourtCalibrationSetupArea"))
                        .onChanged { value in
                            activeDraggingIndex = i
                            guard viewSize.width > 0 && viewSize.height > 0 else { return }
                            let touchNorm = CGPoint(
                                x: value.location.x / viewSize.width,
                                y: value.location.y / viewSize.height
                            )
                            CourtGeometryHelper.updateCorner(corners: &corners, index: i, rawTouch: touchNorm)
                        }
                        .onEnded { _ in
                            activeDraggingIndex = nil
                        }
                )
            }
        }
    }
    
    private func colorForLandmark(_ index: Int) -> Color {
        switch index {
        case 0...3:
            return Color.yellow  // 4 Góc ngoài sân
        case 4...7:
            return Color.orange  // 4 Điểm vạch bếp
        case 8...9:
            return Color.cyan    // 2 Điểm cột lưới
        default:
            return Color.white
        }
    }
}
