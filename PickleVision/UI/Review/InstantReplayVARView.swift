//
//  InstantReplayVARView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  VAR Instant Replay with 4x Magnifying Loupe, USA Pickleball Line Judgement & Slow-Mo 5s Scrubber.
//

import SwiftUI

/// Dữ liệu phục vụ phán quyết VAR Instant Replay
public struct VARDecisionData: Identifiable, Equatable {
    public let id = UUID()
    public let bounceCourtCoordinate: CGPoint   // Tọa độ mét trên sân (X, Y)
    public let bouncePixelCoordinate: CGPoint   // Tọa độ pixel trên camera (u, v)
    public let decision: InOutVerdict          // Phán quyết IN / OUT / FAULT
    public let marginCm: Double                 // Sai lệch tới vạch gần nhất (cm)
    public let timestamp: TimeInterval
    public let isServe: Bool                    // Có phải pha giao bóng hay không
    
    public init(
        bounceCourtCoordinate: CGPoint,
        bouncePixelCoordinate: CGPoint,
        decision: InOutVerdict,
        marginCm: Double,
        timestamp: TimeInterval,
        isServe: Bool = false
    ) {
        self.bounceCourtCoordinate = bounceCourtCoordinate
        self.bouncePixelCoordinate = bouncePixelCoordinate
        self.decision = decision
        self.marginCm = marginCm
        self.timestamp = timestamp
        self.isServe = isServe
    }
}

/// Giao diện xem lại VAR / Slow-motion cận cảnh điểm chạm bóng
public struct InstantReplayVARView: View {
    
    // MARK: - Properties
    
    public let event: VARDecisionData
    public var onClose: () -> Void
    public var onManualOverride: ((InOutVerdict) -> Void)? = nil
    
    // States
    @State private var playbackRate: Float = 0.25
    @State private var currentFrameIndex: Int = 75 // 5s clip @ 30fps = 150 frames, giữa là điểm nảy
    @State private var isPlaying: Bool = true
    
    public init(
        event: VARDecisionData,
        onClose: @escaping () -> Void,
        onManualOverride: ((InOutVerdict) -> Void)? = nil
    ) {
        self.event = event
        self.onClose = onClose
        self.onManualOverride = onManualOverride
    }
    
    // MARK: - Decision Styling & Rule Rationale
    
    private var isFaultOrOut: Bool {
        return event.decision.isFaultOrOut
    }
    
    private var decisionColor: Color {
        return isFaultOrOut ? Color(red: 0.95, green: 0.22, blue: 0.25) : Color(red: 0.12, green: 0.88, blue: 0.45)
    }
    
    private var ruleExplanation: String {
        if event.isServe {
            if isFaultOrOut {
                return "LUẬT USAP 4.A.2: Vạch Bếp (NVZ Line) KHÔNG thuộc ô giao bóng hợp lệ. Bóng liếm vạch bếp là FAULT!"
            } else {
                return "LUẬT USAP 4.A.2: Vạch biên, vạch đáy và vạch giữa thuộc ô giao bóng hợp lệ (IN)!"
            }
        } else {
            if event.decision == .inBound {
                return "LUẬT USAP 2.B.3 & 6.A: Bóng chạm vạch hoặc rơi trong khu vực bếp trong pha bóng sống là HOÀN TOÀN HỢP LỆ (IN)!"
            } else {
                return "LUẬT USAP 6.A: Quả bóng đã rơi trọn vẹn bên ngoài mép ngoài của vạch biên/đáy (OUT)!"
            }
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack {
            // Nền tối mờ toàn màn hình
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            VStack(spacing: 16) {
                
                // 1. Header VAR Title & Đóng
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "video.badge.waveform.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(decisionColor)
                        
                        Text("HAWK-EYE VAR INSTANT REPLAY")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                
                // 2. KÍNH LÚP PHÓNG ĐẠI QUANG HỌC 4X (MAGNIFYING LOUPE 4X)
                ZStack {
                    // Vùng kính lúp hình tròn phóng to
                    Circle()
                        .fill(Color(red: 0.08, green: 0.22, blue: 0.38))
                        .frame(width: 230, height: 230)
                        .overlay(
                            // Giả lập vạch sân màu trắng phóng to 4x
                            Rectangle()
                                .fill(Color.white.opacity(0.95))
                                .frame(width: 18, height: 230)
                                .offset(x: -20)
                        )
                        .overlay(
                            // Quả bóng Pickleball phóng to biến dạng khi nén tiếp đất
                            ZStack {
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 36, height: 36)
                                
                                // Họa tiết lỗ bóng pickleball
                                Circle().fill(Color.black.opacity(0.35)).frame(width: 4, height: 4).offset(x: -6, y: -6)
                                Circle().fill(Color.black.opacity(0.35)).frame(width: 4, height: 4).offset(x: 6, y: -4)
                                Circle().fill(Color.black.opacity(0.35)).frame(width: 4, height: 4).offset(x: -3, y: 7)
                                Circle().fill(Color.black.opacity(0.35)).frame(width: 4, height: 4).offset(x: 7, y: 7)
                            }
                            .offset(x: isFaultOrOut ? 18 : -14, y: 0)
                        )
                        .overlay(
                            // Tâm ngắm quang học Reticle Crosshair
                            ZStack {
                                Rectangle().fill(decisionColor.opacity(0.65)).frame(width: 1, height: 230)
                                Rectangle().fill(decisionColor.opacity(0.65)).frame(width: 230, height: 1)
                                Circle().stroke(decisionColor, lineWidth: 1.5).frame(width: 46, height: 46)
                            }
                        )
                        .clipShape(Circle())
                        .overlay(
                            // Vòng viền phát sáng phán quyết 4x
                            Circle()
                                .stroke(decisionColor, lineWidth: 4.5)
                                .shadow(color: decisionColor.opacity(0.85), radius: 16)
                        )
                    
                    // Badge 4X Magnification
                    VStack {
                        HStack {
                            Text("ZOOM 4X")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.75))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        Spacer()
                    }
                    .frame(width: 230, height: 230)
                }
                
                // 3. Banner Phán Quyết Lớn & Thước Đo Sai Lệch Milimet
                VStack(spacing: 4) {
                    Text(isFaultOrOut ? "FAULT / OUT" : "IN (HỢP LỆ)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(decisionColor)
                        .shadow(color: decisionColor.opacity(0.6), radius: 10)
                    
                    // Khoảng cách milimet
                    Text(String(format: "%@ %.1f mm", isFaultOrOut ? "-" : "+", abs(event.marginCm * 10.0)))
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("KHOẢNG CÁCH TIẾP XÚC TỚI VẠCH SÂN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                    
                    // Giải thích luật USA Pickleball
                    Text(ruleExplanation)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }
                
                // 4. BỘ ĐIỀU KHIỂN SLOW-MOTION 5s VÀ TUA TỪNG KHUNG HÌNH (SCRUBBER)
                VStack(spacing: 12) {
                    
                    // Scrubber Frame Slider (0 đến 150 khung hình)
                    VStack(spacing: 2) {
                        Slider(
                            value: Binding(
                                get: { Double(currentFrameIndex) },
                                set: { currentFrameIndex = Int($0) }
                            ),
                            in: 0...150
                        )
                        .tint(decisionColor)
                        
                        HStack {
                            Text("-2.5s (Tiếp cận)")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("Frame \(currentFrameIndex) / 150 (Chạm sân)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("+2.5s (Sau nảy)")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Tốc độ Slow-Mo & Nút Tua
                    HStack(spacing: 16) {
                        // Nút Tạm Dừng / Tiếp Tục
                        Button(action: {
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        
                        // Các nấc tốc độ tua
                        SpeedButton(rate: 0.25, currentRate: playbackRate) { playbackRate = 0.25 }
                        SpeedButton(rate: 0.50, currentRate: playbackRate) { playbackRate = 0.50 }
                        SpeedButton(rate: 1.00, currentRate: playbackRate) { playbackRate = 1.00 }
                        
                        Spacer()
                        
                        // Đính chính phán quyết thủ công của trọng tài / HLV
                        Menu {
                            Button("Đổi sang IN (Hợp lệ)") {
                                onManualOverride?(.inBound)
                                onClose()
                            }
                            Button("Đổi sang OUT (Ngoài sân)") {
                                onManualOverride?(.outOfBound)
                                onClose()
                            }
                            Button("Đổi sang FAULT (Lỗi bếp)") {
                                onManualOverride?(.faultKitchenServe)
                                onClose()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                Text("ĐÍNH CHÍNH")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.17))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.65), radius: 35)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Speed Button Helper

private struct SpeedButton: View {
    let rate: Float
    let currentRate: Float
    let action: () -> Void
    
    var isSelected: Bool {
        return abs(rate - currentRate) < 0.01
    }
    
    var body: some View {
        Button(action: action) {
            Text(String(format: "%.2fx", rate))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.yellow : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
