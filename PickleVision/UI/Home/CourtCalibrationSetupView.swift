//
//  CourtCalibrationSetupView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-06.
//  Step 2: Fullscreen Clean Court ROI Calibration Setup Screen without UI Bars.
//  Supports 10 Calibration Landmark Points: 4 Outer Corners + 4 Kitchen Points + 2 Net Points.
//

import SwiftUI
import CoreVideo

/// Màn hình căn chỉnh ROI 10 điểm sân thi đấu trước khi vào trận chính
public struct CourtCalibrationSetupView: View {
    
    // MARK: - Default 10 Landmark Points (Normalized [0...1])
    public static let default10Points: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.88),  // 0: Đáy Gần Trái
        CGPoint(x: 0.88, y: 0.88),  // 1: Đáy Gần Phải
        CGPoint(x: 0.68, y: 0.22),  // 2: Đáy Xa Phải
        CGPoint(x: 0.32, y: 0.22),  // 3: Đáy Xa Trái
        CGPoint(x: 0.23, y: 0.58),  // 4: Bếp Gần Trái
        CGPoint(x: 0.77, y: 0.58),  // 5: Bếp Gần Phải
        CGPoint(x: 0.71, y: 0.36),  // 6: Bếp Xa Phải
        CGPoint(x: 0.29, y: 0.36),  // 7: Bếp Xa Trái
        CGPoint(x: 0.26, y: 0.46),  // 8: Chân Lưới Trái
        CGPoint(x: 0.74, y: 0.46)   // 9: Chân Lưới Phải
    ]
    
    // MARK: - Properties & Callbacks
    
    @Binding public var currentFrameBuffer: CVPixelBuffer?
    public var initialCorners: [CGPoint]
    public var onBack: () -> Void
    public var onNext: (_ calibratedCorners: [CGPoint]) -> Void
    
    // MARK: - Local States
    
    @State private var calibrationCorners: [CGPoint]
    @State private var interactionMode: CameraPreviewInteractionMode = .courtCalibration(selectedCornerIndex: 0)
    
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
                
                // 2. Lớp Đa Giác ROI 10 Điểm Sân (4 Góc + 4 Bếp + 2 Lưới) & Chốt Kéo Thả
                CalibrationROIOverlay(
                    corners: calibrationCorners,
                    viewSize: geometry.size
                )
                
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
                                Image(systemName: "camera.metering.matrix")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12, weight: .bold))
                                Text("CĂN CHỈNH 10 ĐIỂM SÂN (4 GÓC • 4 BẾP • 2 LƯỚI)")
                                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            Text("Chạm & kéo các chốt: Vàng (4 Góc), Cam (4 Bếp), Xanh ngọc (2 Lưới)")
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
                    .background(.ultraThinMaterial.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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

// MARK: - Subview: Lớp Vẽ Đa Giác ROI 10 Điểm & Chốt Kéo Thả

private struct CalibrationROIOverlay: View {
    let corners: [CGPoint]
    let viewSize: CGSize
    
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
            Canvas { context, size in
                let pts = corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                
                // 1. Vẽ Viền Sân Ngoài (Corners 0 -> 1 -> 2 -> 3 -> 0)
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
                
                // 2. Vẽ Vùng Bếp Non-Volley Zone (Kitchen: 4 -> 5 -> 6 -> 7)
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
                
                // 3. Vẽ Đường Mép Lưới (Net: 8 -> 9)
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
                
                // 4. Vẽ Đường Phân Chia Ô Phát Bóng (Centerlines)
                if pts.count >= 8 {
                    // Centerline sân gần: Trung điểm (0, 1) đến trung điểm (4, 5)
                    let midNearBL = CGPoint(x: (pts[0].x + pts[1].x) / 2.0, y: (pts[0].y + pts[1].y) / 2.0)
                    let midNearNVZ = CGPoint(x: (pts[4].x + pts[5].x) / 2.0, y: (pts[4].y + pts[5].y) / 2.0)
                    var nearCenterPath = Path()
                    nearCenterPath.move(to: midNearBL)
                    nearCenterPath.addLine(to: midNearNVZ)
                    context.stroke(nearCenterPath, with: .color(Color.cyan.opacity(0.7)), lineWidth: 1.5)
                    
                    // Centerline sân xa: Trung điểm (3, 2) đến trung điểm (7, 6)
                    let midFarBL = CGPoint(x: (pts[3].x + pts[2].x) / 2.0, y: (pts[3].y + pts[2].y) / 2.0)
                    let midFarNVZ = CGPoint(x: (pts[7].x + pts[6].x) / 2.0, y: (pts[7].y + pts[6].y) / 2.0)
                    var farCenterPath = Path()
                    farCenterPath.move(to: midFarBL)
                    farCenterPath.addLine(to: midFarNVZ)
                    context.stroke(farCenterPath, with: .color(Color.cyan.opacity(0.7)), lineWidth: 1.5)
                }
            }
            
            // 10 Chốt ghim kéo thả với màu sắc phân loại trực quan
            ForEach(0..<corners.count, id: \.self) { i in
                let corner = corners[i]
                let px = corner.x * viewSize.width
                let py = corner.y * viewSize.height
                let color = colorForLandmark(i)
                
                VStack(spacing: 2) {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.0))
                        .shadow(color: color.opacity(0.9), radius: 6)
                    
                    Text(landmarkNames[min(i, landmarkNames.count - 1)])
                        .font(.system(size: 8.5, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                }
                .position(x: px, y: py)
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
