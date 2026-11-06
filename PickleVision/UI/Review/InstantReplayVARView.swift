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
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
            
            VStack(spacing: 10) {
                
                // 1. Header Bar: Tiêu đề VAR HAWK-EYE + Nút Đóng
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "video.badge.waveform.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(decisionColor)
                        
                        Text("HAWK-EYE VAR INSTANT REPLAY")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // 2. BỐ CỤC 2 CỘT NẰM NGANG (Landscape Layout)
                HStack(alignment: .top, spacing: 16) {
                    
                    // CỘT TRÁI: KÍNH LÚP 4X VÀ BỘ ĐIỀU KHIỂN SLOW-MO
                    VStack(spacing: 6) {
                        // Kính lúp phóng đại quang học 4x (đường kính 150pt)
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.08, green: 0.22, blue: 0.38))
                                .frame(width: 150, height: 150)
                                .overlay(
                                    // Giả lập vạch sân màu trắng phóng to 4x
                                    Rectangle()
                                        .fill(Color.white.opacity(0.95))
                                        .frame(width: 14, height: 150)
                                        .offset(x: -16)
                                )
                                .overlay(
                                    // Quả bóng Pickleball phóng to biến dạng khi nén tiếp đất
                                    ZStack {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 30, height: 30)
                                        
                                        Circle().fill(Color.black.opacity(0.35)).frame(width: 3.5, height: 3.5).offset(x: -5, y: -5)
                                        Circle().fill(Color.black.opacity(0.35)).frame(width: 3.5, height: 3.5).offset(x: 5, y: -3)
                                        Circle().fill(Color.black.opacity(0.35)).frame(width: 3.5, height: 3.5).offset(x: -2, y: 6)
                                        Circle().fill(Color.black.opacity(0.35)).frame(width: 3.5, height: 3.5).offset(x: 6, y: 6)
                                    }
                                    .offset(x: isFaultOrOut ? 16 : -12, y: 0)
                                )
                                .overlay(
                                    // Tâm ngắm quang học Reticle Crosshair
                                    ZStack {
                                        Rectangle().fill(decisionColor.opacity(0.65)).frame(width: 1, height: 150)
                                        Rectangle().fill(decisionColor.opacity(0.65)).frame(width: 150, height: 1)
                                        Circle().stroke(decisionColor, lineWidth: 1.5).frame(width: 36, height: 36)
                                    }
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(decisionColor, lineWidth: 3.5)
                                        .shadow(color: decisionColor.opacity(0.85), radius: 10)
                                )
                            
                            // Badge 4X Magnification
                            VStack {
                                HStack {
                                    Text("ZOOM 4X")
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2.5)
                                        .background(Color.black.opacity(0.75))
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                Spacer()
                            }
                            .frame(width: 150, height: 150)
                        }
                        
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
                            
                            HStack(spacing: 6) {
                                Button(action: { isPlaying.toggle() }) {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .frame(width: 22, height: 22)
                                        .background(Color.white.opacity(0.12))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                SpeedButton(rate: 0.25, currentRate: playbackRate) { playbackRate = 0.25 }
                                SpeedButton(rate: 0.50, currentRate: playbackRate) { playbackRate = 0.50 }
                                SpeedButton(rate: 1.00, currentRate: playbackRate) { playbackRate = 1.00 }
                                
                                Spacer()
                                
                                Text("F\(currentFrameIndex)/150")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .frame(width: 210)
                    }
                    
                    // CỘT PHẢI: PHÁN QUYẾT, THƯỚC ĐO MM, GIẢI THÍCH LUẬT & NÚT HÀNH ĐỘNG
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // Banner Phán Quyết Lớn & Thước Đo Sai Lệch Milimet
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Text(isFaultOrOut ? "FAULT / OUT" : "IN (HỢP LỆ)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(decisionColor)
                                .shadow(color: decisionColor.opacity(0.6), radius: 8)
                            
                            Text(String(format: "%@ %.1f mm", isFaultOrOut ? "-" : "+", abs(event.marginCm * 10.0)))
                                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Text("tới vạch")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        
                        // Khung giải thích luật USA Pickleball
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(decisionColor)
                                    .font(.system(size: 9))
                                Text("LUẬT USA PICKLEBALL ÁP DỤNG:")
                                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            
                            Text(ruleExplanation)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        
                        Spacer()
                        
                        // Hàng nút: Đính chính & Xác nhận phán quyết
                        HStack(spacing: 10) {
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
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.15))
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            Button(action: onClose) {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("XÁC NHẬN")
                                        .font(.system(size: 11, weight: .black))
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
                                .shadow(color: Color.green.opacity(0.5), radius: 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: 630, maxHeight: 275)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.15).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.7), radius: 25)
            .padding(.horizontal, 16)
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
