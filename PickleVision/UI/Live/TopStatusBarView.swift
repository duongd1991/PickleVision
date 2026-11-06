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
    public var isRecording: Bool = true
    public var onCalibrationTapped: (() -> Void)? = nil
    public var onHomeTapped: (() -> Void)? = nil
    
    public init(
        rallyDuration: TimeInterval,
        rallyIndex: Int,
        shotExchanges: Int,
        effectivePlayTime: TimeInterval,
        rallyState: RallyState,
        matchScore: MatchScore = MatchScore(),
        isCalibrated: Bool = true,
        isRecording: Bool = true,
        onCalibrationTapped: (() -> Void)? = nil,
        onHomeTapped: (() -> Void)? = nil
    ) {
        self.rallyDuration = rallyDuration
        self.rallyIndex = rallyIndex
        self.shotExchanges = shotExchanges
        self.effectivePlayTime = effectivePlayTime
        self.rallyState = rallyState
        self.matchScore = matchScore
        self.isCalibrated = isCalibrated
        self.isRecording = isRecording
        self.onCalibrationTapped = onCalibrationTapped
        self.onHomeTapped = onHomeTapped
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
        HStack(spacing: 6) {
            
            // 0. Nút Home quay về trang chủ
            if let onHome = onHomeTapped {
                Button(action: onHome) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(5)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.2))
            }
            
            // 1. Tỷ số trận đấu (Side-out score)
            ScoreBoardBadge(score: matchScore)
            
            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
            
            // 2. Thời gian pha cầu hiện tại
            MetricPill(
                title: "PHA CẦU",
                value: formattedRallyTime,
                icon: "stopwatch.fill",
                accentColor: .yellow
            )
            
            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
            
            // 3. Pha số
            MetricPill(
                title: "PHA SỐ",
                value: "#\(rallyIndex)",
                icon: "number.square.fill",
                accentColor: .white
            )
            
            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
            
            // 4. Lượt cầu đổi hướng (Shot exchanges)
            MetricPill(
                title: "ĐỔI HƯỚNG",
                value: "\(shotExchanges)",
                icon: "arrow.left.and.right.square.fill",
                accentColor: .cyan
            )
            
            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
            
            // 5. Thời gian chơi thực tích lũy
            MetricPill(
                title: "T.GIAN CHƠI",
                value: formattedPlayTime,
                icon: "clock.badge.checkmark.fill",
                accentColor: Color(red: 0.2, green: 0.9, blue: 0.7)
            )
            
            Spacer(minLength: 2)
            
            // Nút trạng thái hiệu chuẩn sân
            Button(action: {
                onCalibrationTapped?()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isCalibrated ? "camera.metering.matrix" : "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isCalibrated ? .green : .yellow)
                    Text(isCalibrated ? "ĐÃ KHỚP" : "CĂN CHỈNH")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(isCalibrated ? .white.opacity(0.85) : .yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
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
            LiveRallyStatePill(state: rallyState, isRecording: isRecording)
            
            // Badge phiên bản v1.0.3
            Text("v1.0.3")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(Color.yellow.opacity(0.18))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Subcomponents

private struct ScoreBoardBadge: View {
    let score: MatchScore
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(score.servingTeam == .nearTeam ? "GẦN GIAO" : "XA GIAO")
                    .font(.system(size: 7.5, weight: .black))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(score.displayString)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accentColor)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(value)
                    .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

private struct LiveRallyStatePill: View {
    let state: RallyState
    var isRecording: Bool = true
    
    @State private var isPulsing: Bool = false
    
    private var pillConfig: (text: String, color: Color, isLive: Bool) {
        if !isRecording {
            return ("CHƯA QUAY", Color.orange, false)
        }
        
        switch state {
        case .waitingForServe:
            return ("CHỜ GIAO", Color(red: 0.25, green: 0.6, blue: 1.0), false)
        case .serveInFlight:
            return ("GIAO BÓNG", Color.yellow, true)
        case .inProgress:
            return ("ĐANG ĐÁNH", Color(red: 0.15, green: 0.88, blue: 0.45), true)
        case .ended(let reason, _):
            switch reason {
            case .ballOut:
                return ("BÓNG OUT", Color(red: 0.95, green: 0.25, blue: 0.25), false)
            case .kitchenFaultServe:
                return ("LỖI BẾP", Color(red: 0.95, green: 0.25, blue: 0.25), false)
            case .doubleBounce:
                return ("2 LẦN NẢY", Color.orange, false)
            case .netFault:
                return ("VƯỚNG LƯỚI", Color.orange, false)
            default:
                return ("HẾT PHA", Color.orange, false)
            }
        }
    }
    
    var body: some View {
        let config = pillConfig
        
        HStack(spacing: 4) {
            Circle()
                .fill(config.color)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(config.color.opacity(0.6), lineWidth: 1.5)
                        .scaleEffect(config.isLive && isPulsing ? 2.0 : 1.0)
                        .opacity(config.isLive && isPulsing ? 0.0 : 0.8)
                )
            
            Text(config.text)
                .font(.system(size: 9.5, weight: .black))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(config.color.opacity(0.22))
                .overlay(
                    Capsule().stroke(config.color.opacity(0.75), lineWidth: 1.0)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
