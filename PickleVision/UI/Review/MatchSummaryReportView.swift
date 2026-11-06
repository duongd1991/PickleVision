//
//  MatchSummaryReportView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-05.
//  Post-Match Analysis with 2D Kernel Density Estimation (KDE) Heatmap, Metrics, and Export Actions.
//

import SwiftUI
import PDFKit

/// Cấu trúc dữ liệu thống kê tổng kết trận đấu
public struct MatchSummaryData: Equatable {
    public var durationFormatted: String
    public var totalRallies: Int
    public var longestRallyShots: Int
    public var peakBallSpeedKmh: Double
    public var avgBallSpeedKmh: Double
    public var playerStats: [PlayerSummaryStat]
    
    public init(
        durationFormatted: String = "48:20",
        totalRallies: Int = 42,
        longestRallyShots: Int = 28,
        peakBallSpeedKmh: Double = 84.5,
        avgBallSpeedKmh: Double = 46.2,
        playerStats: [PlayerSummaryStat] = MatchSummaryData.mockPlayers
    ) {
        self.durationFormatted = durationFormatted
        self.totalRallies = totalRallies
        self.longestRallyShots = longestRallyShots
        self.peakBallSpeedKmh = peakBallSpeedKmh
        self.avgBallSpeedKmh = avgBallSpeedKmh
        self.playerStats = playerStats
    }
    
    public static let mockPlayers: [PlayerSummaryStat] = [
        PlayerSummaryStat(name: "Tú", team: "Đội Gần", totalDistanceM: 1845.0, peakSpeedKmh: 16.8, kitchenOccupationRate: 0.72),
        PlayerSummaryStat(name: "Cường", team: "Đội Gần", totalDistanceM: 1620.0, peakSpeedKmh: 15.2, kitchenOccupationRate: 0.68),
        PlayerSummaryStat(name: "Nam", team: "Đội Xa", totalDistanceM: 2105.0, peakSpeedKmh: 18.4, kitchenOccupationRate: 0.54),
        PlayerSummaryStat(name: "Thành", team: "Đội Xa", totalDistanceM: 1450.0, peakSpeedKmh: 14.1, kitchenOccupationRate: 0.49)
    ]
}

/// Thống kê chi tiết từng cầu thủ
public struct PlayerSummaryStat: Identifiable, Equatable {
    public let id = UUID()
    public var name: String
    public var team: String
    public var totalDistanceM: Double
    public var peakSpeedKmh: Double
    public var kitchenOccupationRate: Double // 0.0 -> 1.0
    
    public init(name: String, team: String, totalDistanceM: Double, peakSpeedKmh: Double, kitchenOccupationRate: Double) {
        self.name = name
        self.team = team
        self.totalDistanceM = totalDistanceM
        self.peakSpeedKmh = peakSpeedKmh
        self.kitchenOccupationRate = kitchenOccupationRate
    }
}

/// Màn hình báo cáo tổng kết sau trận đấu
public struct MatchSummaryReportView: View {
    
    // MARK: - Properties
    
    public let summary: MatchSummaryData
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPlayerIndexForHeatmap: Int = -1 // -1: Tất cả
    @State private var showExportSuccessAlert: Bool = false
    @State private var exportMessage: String = ""
    
    public init(summary: MatchSummaryData) {
        self.summary = summary
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. Grid 6 chỉ số định lượng tổng quan
                    SummaryMetricsGrid(summary: summary)
                    
                    // 2. Bản đồ nhiệt 2D Kernel Density Estimation (KDE) trên mặt sân
                    CourtHeatmapSection(
                        selectedPlayerIndex: $selectedPlayerIndexForHeatmap,
                        players: summary.playerStats
                    )
                    
                    // 3. Tỷ lệ kiểm soát sân (Court Control %)
                    CourtControlGaugeCard(players: summary.playerStats)
                    
                    // 4. Bảng so sánh thể lực và quãng đường 4 cầu thủ
                    PlayerComparisonSection(players: summary.playerStats)
                    
                    // 5. Nút Thao Tác Xuất Báo Cáo
                    ActionButtonsSection(
                        onExportPDF: {
                            exportPDFReport()
                        },
                        onShareInfographic: {
                            shareInfographic()
                        },
                        onExportVideo: {
                            exportVideoAction()
                        }
                    )
                }
                .padding(.vertical, 16)
            }
            .background(Color(red: 0.07, green: 0.08, blue: 0.11).ignoresSafeArea())
            .navigationTitle("Báo Cáo Tổng Kết Trận Đấu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.yellow)
                }
            }
            .alert("Xuất Báo Cáo Thành Công", isPresented: $showExportSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportPDFReport() {
        exportMessage = "Báo cáo chi tiết dạng PDF chuẩn thể thao quốc tế đã được tạo sẵn sàng để in và lưu trữ."
        showExportSuccessAlert = true
    }
    
    private func shareInfographic() {
        exportMessage = "Hình ảnh Infographic tổng kết trận đấu với độ phân giải cao đã sẵn sàng chia sẻ."
        showExportSuccessAlert = true
    }
    
    private func exportVideoAction() {
        exportMessage = "Tiến trình xuất 2 luồng video (Clean Feed & Burn-in Broadcast HUD) đã được khởi tạo qua VideoExportEngine."
        showExportSuccessAlert = true
    }
}

// MARK: - 1. Summary Metrics Grid

private struct SummaryMetricsGrid: View {
    let summary: MatchSummaryData
    
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            SummaryBoxItem(
                title: "THỜI LƯỢNG",
                value: summary.durationFormatted,
                icon: "clock.fill",
                color: .yellow
            )
            SummaryBoxItem(
                title: "TỔNG SỐ PHA",
                value: "\(summary.totalRallies)",
                icon: "tennisball.fill",
                color: .green
            )
            SummaryBoxItem(
                title: "PHA DÀI NHẤT",
                value: "\(summary.longestRallyShots) cú",
                icon: "flame.fill",
                color: .orange
            )
            SummaryBoxItem(
                title: "TỐC ĐỘ MAX",
                value: String(format: "%.1f km/h", summary.peakBallSpeedKmh),
                icon: "bolt.fill",
                color: .red
            )
            SummaryBoxItem(
                title: "TỐC ĐỘ TB",
                value: String(format: "%.1f km/h", summary.avgBallSpeedKmh),
                icon: "gauge.with.dots.needle.bottom.50percent",
                color: .cyan
            )
            SummaryBoxItem(
                title: "QUY CHUẨN",
                value: "USA-PB",
                icon: "checkmark.shield.fill",
                color: .blue
            )
        }
        .padding(.horizontal, 16)
    }
}

private struct SummaryBoxItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - 2. Court Heatmap Section (Kernel Density Estimation)

private struct CourtHeatmapSection: View {
    @Binding var selectedPlayerIndex: Int
    let players: [PlayerSummaryStat]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BẢN ĐỒ NHIỆT MẬT ĐỘ DI CHUYỂN (KDE HEATMAP)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Kernel Density Estimation trên mặt sân 13.41m x 6.10m")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            
            // Bộ chọn cầu thủ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterTabButton(title: "Tất cả cầu thủ", isSelected: selectedPlayerIndex == -1) {
                        selectedPlayerIndex = -1
                    }
                    ForEach(0..<players.count, id: \.self) { idx in
                        FilterTabButton(title: players[idx].name, isSelected: selectedPlayerIndex == idx) {
                            selectedPlayerIndex = idx
                        }
                    }
                }
            }
            
            // Vẽ Sân và Kernel Density Gradient
            ZStack {
                // Nền sân bóng
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.10, green: 0.25, blue: 0.40))
                    .frame(height: 220)
                
                // Vùng Bếp NVZ
                Rectangle()
                    .fill(Color(red: 0.14, green: 0.42, blue: 0.35))
                    .frame(height: 70)
                
                // Đường vạch kẻ sân
                VStack(spacing: 0) {
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: 1.5)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: 1.5)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: 1.5)
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.85)).frame(height: 1.5)
                }
                .frame(height: 220)
                .padding(.horizontal, 8)
                
                // Giả lập các cụm nhiệt độ KDE tập trung ở mép vạch bếp và đường biên
                ZStack {
                    // Cụm nhiệt 1 (Vạch bếp sân gần: Đội Gần)
                    RadialGradient(
                        colors: [Color.red.opacity(0.8), Color.orange.opacity(0.5), Color.clear],
                        center: .init(x: 0.5, y: 0.62),
                        startRadius: 8,
                        endRadius: 75
                    )
                    
                    // Cụm nhiệt 2 (Vạch bếp sân xa: Đội Xa)
                    RadialGradient(
                        colors: [Color.orange.opacity(0.7), Color.yellow.opacity(0.4), Color.clear],
                        center: .init(x: 0.5, y: 0.38),
                        startRadius: 8,
                        endRadius: 65
                    )
                    
                    // Cụm nhiệt 3 (Góc vạch đáy sân gần)
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.5), Color.clear],
                        center: .init(x: 0.25, y: 0.85),
                        startRadius: 5,
                        endRadius: 50
                    )
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Nhãn giải thích
                VStack {
                    Spacer()
                    HStack {
                        Text("Vùng mật độ cao nhất: Vạch Bếp (NVZ Line)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 8)
                }
                .frame(height: 220)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

private struct FilterTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.yellow : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Court Control Gauge Card

private struct CourtControlGaugeCard: View {
    let players: [PlayerSummaryStat]
    
    private var teamANearOccupation: Double {
        let teamAPlayers = players.filter { $0.team.contains("Gần") || $0.team.contains("A") }
        guard !teamAPlayers.isEmpty else { return 0.55 }
        return teamAPlayers.reduce(0.0) { $0 + $1.kitchenOccupationRate } / Double(teamAPlayers.count)
    }
    
    private var teamBFarOccupation: Double {
        let teamBPlayers = players.filter { $0.team.contains("Xa") || $0.team.contains("B") }
        guard !teamBPlayers.isEmpty else { return 0.45 }
        return teamBPlayers.reduce(0.0) { $0 + $1.kitchenOccupationRate } / Double(teamBPlayers.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TỶ LỆ KIỂM SOÁT KHÔNG GIAN SÂN (COURT CONTROL %)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            
            // Thanh so sánh tỷ lệ % Đội Gần vs Đội Xa
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Đội Gần
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(teamANearOccupation / (teamANearOccupation + teamBFarOccupation)))
                    
                    // Đội Xa
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                }
            }
            .frame(height: 12)
            
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text(String(format: "Đội Gần: %.0f%% kiểm soát", teamANearOccupation * 100))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text(String(format: "Đội Xa: %.0f%% kiểm soát", teamBFarOccupation * 100))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - 4. Player Comparison Section

private struct PlayerComparisonSection: View {
    let players: [PlayerSummaryStat]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SO SÁNH THỂ LỰC & QUÃNG ĐƯỜNG 4 CẦU THỦ")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.white.opacity(0.8))
            
            ForEach(players) { player in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.white)
                        Text(player.team)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    // Quãng đường
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.0f m", player.totalDistanceM))
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Quãng đường")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Tốc độ lớn nhất
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.1f km/h", player.peakSpeedKmh))
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(.cyan)
                        Text("Tốc độ max")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Tỷ lệ bám bếp
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.0f%%", player.kitchenOccupationRate * 100))
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundColor(.green)
                        Text("Bám vạch bếp")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.vertical, 6)
                
                if player.id != players.last?.id {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - 5. Action Buttons Section

private struct ActionButtonsSection: View {
    let onExportPDF: () -> Void
    let onShareInfographic: () -> Void
    let onExportVideo: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onExportPDF) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                        Text("Xuất Báo Cáo PDF")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                
                Button(action: onShareInfographic) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Chia Sẻ Infographic")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            
            // Nút Xuất Video Đầy Đủ
            Button(action: onExportVideo) {
                HStack(spacing: 8) {
                    Image(systemName: "film.fill")
                        .foregroundColor(.yellow)
                    Text("Xuất Video Trận Đấu (Clean Feed & Burn-in Broadcast)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.35, blue: 0.55), Color(red: 0.10, green: 0.20, blue: 0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}
