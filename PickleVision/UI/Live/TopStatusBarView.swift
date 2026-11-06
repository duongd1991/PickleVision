//
//  TopStatusBarView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Ultra-thin Material Live Status Bar for Rally Telemetry and Real-Time Match State.
//

import SwiftUI

/// Thanh trạng thái phía trên màn hình hiển thị số liệu pha bóng và trạng thái thời gian thực
public struct TopStatusBarView: View {
    
    // MARK: - Properties
    
    public let rallyDuration: TimeInterval
    public let rallyIndex: Int
    public let shotExchanges: Int
    public let effectivePlayTime: TimeInterval
    public let rallyState: RallyState
    public let matchScore: MatchScore
    public var isCalibrated: Bool = true
    public var onCalibrationTapped: (() -> Void)? = nil
    
    public init(
        rallyDuration: TimeInterval,
        rallyIndex: Int,
        shotExchanges: Int,
        effectivePlayTime: TimeInterval,
        rallyState: RallyState,
        matchScore: MatchScore = MatchScore(),
        isCalibrated: Bool = true,
        onCalibrationTapped: (() -> Void)? = nil
    ) {
        self.rallyDuration = rallyDuration
        self.rallyIndex = rallyIndex
        self.shotExchanges = shotExchanges
        self.effectivePlayTime = effectivePlayTime
        self.rallyState = rallyState
        self.matchScore = matchScore
        self.isCalibrated = isCalibrated
        self.onCalibrationTapped = onCalibrationTapped
    }
    
    // MARK: - Formatters
    
    private var formattedRallyTime: String {
        let minutes = Int(rallyDuration) / 60
        let seconds = Int(rallyDuration) % 60
        let tenths = Int((rallyDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%1d", minutes, seconds, tenths)
    }
    
    private var formattedPlayTime: String {
        let minutes = Int(effectivePlayTime) / 60
        let seconds = Int(effectivePlayTime) % 60
        let tenths = Int((effectivePlayTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%1d", minutes, seconds, tenths)
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: 12) {
            
            // 1. Tỷ số trận đấu (Side-out score)
            ScoreBoardBadge(score: matchScore)
            
            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.2))
            
            // 2. Thời gian pha cầu hiện tại
            MetricPill(
                title: "THỜI GIAN PHA",
                value: formattedRallyTime,
                icon: "stopwatch.fill",
                accentColor: .yellow
            )
            
            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.2))
            
            // 3. Pha số
            MetricPill(
                title: "PHA SỐ",
                value: "Pha \(rallyIndex)",
                icon: "number.square.fill",
                accentColor: .white
            )
            
            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.2))
            
            // 4. Lượt cầu đổi hướng (Shot exchanges)
            MetricPill(
                title: "LƯỢT ĐỔI HƯỚNG",
                value: "\(shotExchanges)",
                icon: "arrow.left.and.right.square.fill",
                accentColor: .cyan
            )
            
            Divider()
                .frame(height: 24)
                .background(Color.white.opacity(0.2))
            
            // 5. Thời gian chơi thực tích lũy
            MetricPill(
                title: "THỜI GIAN CHƠI",
                value: formattedPlayTime,
                icon: "clock.badge.checkmark.fill",
                accentColor: Color(red: 0.2, green: 0.9, blue: 0.7)
            )
            
            Spacer(minLength: 4)
            
            // Nút trạng thái hiệu chuẩn sân
            Button(action: {
                onCalibrationTapped?()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: isCalibrated ? "camera.metering.matrix" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isCalibrated ? .green : .yellow)
                    Text(isCalibrated ? "SÂN ĐÃ KHỚP" : "CĂN CHỈNH SÂN")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(isCalibrated ? .white.opacity(0.8) : .yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isCalibrated ? Color.white.opacity(0.08) : Color.yellow.opacity(0.2))
                        .overlay(
                            Capsule().stroke(isCalibrated ? Color.white.opacity(0.15) : Color.yellow, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // 6. Trạng thái trực tiếp của trận đấu
            LiveRallyStatePill(state: rallyState)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

// MARK: - Subcomponents

private struct ScoreBoardBadge: View {
    let score: MatchScore
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(score.servingTeam == .nearTeam ? "ĐỘI GẦN GIAO" : "ĐỘI XA GIAO")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(score.displayString)
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
}

private struct MetricPill: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }
}

private struct LiveRallyStatePill: View {
    let state: RallyState
    
    @State private var isPulsing: Bool = false
    
    private var pillConfig: (text: String, color: Color, isLive: Bool) {
        switch state {
        case .waitingForServe:
            return ("CHỜ GIAO BÓNG", Color(red: 0.25, green: 0.6, blue: 1.0), false) // Xanh dương
        case .serveInFlight:
            return ("GIAO BÓNG", Color.yellow, true)
        case .inProgress:
            return ("ĐANG ĐÁNH", Color(red: 0.15, green: 0.88, blue: 0.45), true) // Xanh lá
        case .ended(let reason, _):
            switch reason {
            case .ballOut:
                return ("BÓNG NGOÀI (OUT)", Color(red: 0.95, green: 0.25, blue: 0.25), false)
            case .kitchenFaultServe:
                return ("LỖI BẾP (FAULT)", Color(red: 0.95, green: 0.25, blue: 0.25), false)
            case .doubleBounce:
                return ("2 LẦN NẢY", Color.orange, false)
            case .netFault:
                return ("VƯỚNG LƯỚI", Color.orange, false)
            default:
                return ("KẾT THÚC PHA", Color.orange, false)
            }
        }
    }
    
    var body: some View {
        let config = pillConfig
        
        HStack(spacing: 6) {
            Circle()
                .fill(config.color)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(config.color.opacity(0.6), lineWidth: 2)
                        .scaleEffect(config.isLive && isPulsing ? 2.0 : 1.0)
                        .opacity(config.isLive && isPulsing ? 0.0 : 0.8)
                )
            
            Text(config.text)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(config.color.opacity(0.22))
                .overlay(
                    Capsule().stroke(config.color.opacity(0.75), lineWidth: 1.2)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
