//
//  PlayerMetricsBarView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Bottom Player Telemetry Cards, Workout Intensity Meter, Video Scrubber & VAR Controls.
//

import SwiftUI

/// Thanh hiển thị chỉ số thể lực 4 cầu thủ kèm bộ điều khiển phát lại video và VAR
public struct PlayerMetricsBarView: View {
    
    // MARK: - Properties
    
    public let metrics: [PlayerRallyMetric]
    public var isRecording: Bool = false
    @Binding public var isLivePlayback: Bool
    @Binding public var scrubberProgress: Double // 0.0 -> 1.0
    public var onToggleRecording: (() -> Void)? = nil
    public var onScrubberChanged: ((Double) -> Void)? = nil
    public var onVARTapped: (() -> Void)? = nil
    public var onSummaryTapped: (() -> Void)? = nil
    public var onPlayPauseToggled: (() -> Void)? = nil
    public var onEditPlayersTapped: (() -> Void)? = nil
    
    public init(
        metrics: [PlayerRallyMetric],
        isRecording: Bool = false,
        isLivePlayback: Binding<Bool> = .constant(true),
        scrubberProgress: Binding<Double> = .constant(1.0),
        onToggleRecording: (() -> Void)? = nil,
        onScrubberChanged: ((Double) -> Void)? = nil,
        onVARTapped: (() -> Void)? = nil,
        onSummaryTapped: (() -> Void)? = nil,
        onPlayPauseToggled: (() -> Void)? = nil,
        onEditPlayersTapped: (() -> Void)? = nil
    ) {
        self.metrics = metrics
        self.isRecording = isRecording
        self._isLivePlayback = isLivePlayback
        self._scrubberProgress = scrubberProgress
        self.onToggleRecording = onToggleRecording
        self.onScrubberChanged = onScrubberChanged
        self.onVARTapped = onVARTapped
        self.onSummaryTapped = onSummaryTapped
        self.onPlayPauseToggled = onPlayPauseToggled
        self.onEditPlayersTapped = onEditPlayersTapped
    }
    
    // MARK: - Fallback Players if telemetry is empty
    
    private var displayMetrics: [PlayerRallyMetric] {
        if !metrics.isEmpty {
            return metrics
        }
        // Bộ hiển thị mặc định 4 cầu thủ A1, A2, B1, B2
        return [
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 0,
                name: "A1",
                team: .nearTeam,
                courtPosition: CGPoint(x: 1.5, y: 1.0),
                rallyDistanceMeters: 18.5,
                totalMatchDistanceMeters: 420.0,
                currentSpeedKmh: 14.2,
                workoutIntensity: 0.75
            ),
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 1,
                name: "A2",
                team: .nearTeam,
                courtPosition: CGPoint(x: 4.5, y: 1.0),
                rallyDistanceMeters: 15.2,
                totalMatchDistanceMeters: 385.0,
                currentSpeedKmh: 11.8,
                workoutIntensity: 0.62
            ),
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 2,
                name: "B1",
                team: .farTeam,
                courtPosition: CGPoint(x: 1.5, y: 12.4),
                rallyDistanceMeters: 22.1,
                totalMatchDistanceMeters: 460.0,
                currentSpeedKmh: 16.5,
                workoutIntensity: 0.88
            ),
            PlayerRallyMetric(
                id: UUID(),
                playerIndex: 3,
                name: "B2",
                team: .farTeam,
                courtPosition: CGPoint(x: 4.5, y: 12.4),
                rallyDistanceMeters: 12.8,
                totalMatchDistanceMeters: 310.0,
                currentSpeedKmh: 9.4,
                workoutIntensity: 0.48
            )
        ]
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 8) {
            
            // 1. Thanh điều khiển Scrubber và Nút Thao Tác Nhanh
            HStack(spacing: 10) {
                
                // Nút QUAY VIDEO chuẩn iPhone Camera Shutter
                Button(action: {
                    onToggleRecording?()
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 2.5)
                            .frame(width: 32, height: 32)
                        
                        if isRecording {
                            // Khi đang quay: icon vuông đỏ bo góc chuẩn camera iPhone
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                                .shadow(color: .red.opacity(0.8), radius: 4)
                        } else {
                            // Khi chưa quay: icon tròn đỏ chuẩn camera iPhone (chờ quay)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                                .shadow(color: .red.opacity(0.6), radius: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Nút Trực tiếp (Live indicator)
                Button(action: {
                    isLivePlayback = true
                    scrubberProgress = 1.0
                    onScrubberChanged?(1.0)
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isRecording ? Color.red : Color.gray.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                                    .scaleEffect(isRecording ? 1.8 : 1.0)
                                    .opacity(isRecording ? 0.0 : 0.6)
                            )
                        Text("LIVE")
                            .font(.system(size: 9.5, weight: .black))
                            .foregroundColor(isRecording ? .white : Color.gray.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(isRecording ? Color.red.opacity(0.35) : Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isRecording ? Color.red.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // Nút Play / Pause
                Button(action: {
                    onPlayPauseToggled?()
                }) {
                    Image(systemName: isLivePlayback ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Thanh trượt tua lại Video (Scrubber)
                Slider(
                    value: $scrubberProgress,
                    in: 0.0...1.0,
                    onEditingChanged: { editing in
                        if !editing {
                            if scrubberProgress < 0.98 {
                                isLivePlayback = false
                            } else {
                                isLivePlayback = true
                            }
                            onScrubberChanged?(scrubberProgress)
                        }
                    }
                )
                .tint(.yellow)
                
                // Nút Kích Hoạt VAR Replay
                Button(action: {
                    onVARTapped?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "video.badge.waveform.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("VAR REPLAY")
                            .font(.system(size: 9, weight: .black))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.4), radius: 4)
                }
                .buttonStyle(.plain)
                
                // Nút Đổi Tên Cầu Thủ
                Button(action: {
                    onEditPlayersTapped?()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                        Text("ĐỔI TÊN")
                            .font(.system(size: 8.5, weight: .black))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Nút Tổng Kết Trận Đấu
                Button(action: {
                    onSummaryTapped?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 10, weight: .bold))
                        Text("TỔNG KẾT")
                            .font(.system(size: 8.5, weight: .black))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // 2. Danh sách 4 thẻ cầu thủ xếp ngang đều
            HStack(spacing: 6) {
                ForEach(displayMetrics) { player in
                    PlayerCardView(metric: player)
                        .onTapGesture {
                            onEditPlayersTapped?()
                        }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.38), radius: 14, x: 0, y: 7)
    }
}

// MARK: - Individual Player Card View

private struct PlayerCardView: View {
    let metric: PlayerRallyMetric
    
    private var playerThemeColor: Color {
        switch metric.playerIndex {
        case 0: return Color(red: 0.22, green: 0.52, blue: 0.98) // Xanh dương
        case 1: return Color(red: 0.58, green: 0.38, blue: 0.98) // Tím
        case 2: return Color(red: 0.98, green: 0.46, blue: 0.12) // Cam
        case 3: return Color(red: 0.94, green: 0.28, blue: 0.28) // Đỏ
        default: return .cyan
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            
            // Header: Tên nằm NGANG với số mét cả trận, và nhãn Đội
            HStack(alignment: .center, spacing: 4) {
                Circle()
                    .fill(playerThemeColor)
                    .frame(width: 7, height: 7)
                
                Text(metric.name)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Số mét cả trận nằm NGANG với tên
                Text("\(Int(metric.totalMatchDistanceMeters))m")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.yellow.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Spacer()
                
                Text(metric.team == .nearTeam ? "GẦN" : "XA")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(playerThemeColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(playerThemeColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            // Quãng đường pha hiện tại & Tốc độ tức thời
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", metric.rallyDistanceMeters))
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                Text("m pha")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                
                Spacer()
                
                Text(String(format: "%.0f km/h", metric.currentSpeedKmh))
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            // Thanh đo cường độ vận động (Workout Intensity Bar)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 3.5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green, .yellow, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * CGFloat(min(max(Double(metric.workoutIntensity), 0.0), 1.0)),
                            height: 3.5
                        )
                }
            }
            .frame(height: 3.5)
            .padding(.top, 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(playerThemeColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
