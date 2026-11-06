//
//  PlayerEditSheetView.swift
//  PickleVision
//
//  Created by Frontend Coder on 2026-11-06.
//  Sheet to customize and edit player names and team roster.
//

import SwiftUI

/// Màn hình chỉnh sửa danh sách tên 4 vận động viên thi đấu
public struct PlayerEditSheetView: View {
    
    // MARK: - Properties
    
    public let initialNames: [String]
    public var onSave: ([String]) -> Void
    public var onDismiss: () -> Void
    
    @State private var p0: String = ""
    @State private var p1: String = ""
    @State private var p2: String = ""
    @State private var p3: String = ""
    
    public init(
        initialNames: [String],
        onSave: @escaping ([String]) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.initialNames = initialNames
        self.onSave = onSave
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Đội gần sân (Near Team)
                Section(header: Label("ĐỘI GẦN (SÂN DƯỚI)", systemImage: "figure.tennis").font(.caption.bold())) {
                    HStack {
                        Circle()
                            .fill(Color(red: 0.22, green: 0.52, blue: 0.98))
                            .frame(width: 12, height: 12)
                        Text("Cầu thủ 1 (Trái):")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        TextField("Nhập tên cầu thủ...", text: $p0)
                            .font(.body.weight(.semibold))
                            .autocorrectionDisabled()
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color(red: 0.58, green: 0.38, blue: 0.98))
                            .frame(width: 12, height: 12)
                        Text("Cầu thủ 2 (Phải):")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        TextField("Nhập tên cầu thủ...", text: $p1)
                            .font(.body.weight(.semibold))
                            .autocorrectionDisabled()
                    }
                }
                
                // Section 2: Đội xa sân (Far Team)
                Section(header: Label("ĐỘI XA (SÂN TRÊN)", systemImage: "figure.pickleball").font(.caption.bold())) {
                    HStack {
                        Circle()
                            .fill(Color(red: 0.98, green: 0.46, blue: 0.12))
                            .frame(width: 12, height: 12)
                        Text("Cầu thủ 3 (Trái):")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        TextField("Nhập tên cầu thủ...", text: $p2)
                            .font(.body.weight(.semibold))
                            .autocorrectionDisabled()
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color(red: 0.94, green: 0.28, blue: 0.28))
                            .frame(width: 12, height: 12)
                        Text("Cầu thủ 4 (Phải):")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        TextField("Nhập tên cầu thủ...", text: $p3)
                            .font(.body.weight(.semibold))
                            .autocorrectionDisabled()
                    }
                }
                
                // Nút khôi phục mặc định
                Section {
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Khôi phục tên mặc định (Tú, Cường, Nam, Thành)")
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Chỉnh Sửa Tên Cầu Thủ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saveNames()
                    }
                    .font(.body.bold())
                }
            }
            .onAppear {
                loadInitialNames()
            }
        }
    }
    
    private func loadInitialNames() {
        p0 = initialNames.indices.contains(0) ? initialNames[0] : "Tú"
        p1 = initialNames.indices.contains(1) ? initialNames[1] : "Cường"
        p2 = initialNames.indices.contains(2) ? initialNames[2] : "Nam"
        p3 = initialNames.indices.contains(3) ? initialNames[3] : "Thành"
    }
    
    private func resetToDefaults() {
        p0 = "Tú"
        p1 = "Cường"
        p2 = "Nam"
        p3 = "Thành"
    }
    
    private func saveNames() {
        let trimmedP0 = p0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Tú" : p0
        let trimmedP1 = p1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Cường" : p1
        let trimmedP2 = p2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nam" : p2
        let trimmedP3 = p3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Thành" : p3
        
        onSave([trimmedP0, trimmedP1, trimmedP2, trimmedP3])
        onDismiss()
    }
}
