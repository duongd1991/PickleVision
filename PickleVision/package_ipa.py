#!/usr/bin/env python3
"""
package_ipa.py - Script tự động đóng gói ứng dụng PickleVision thành tệp .ipa
Hỗ trợ định dạng chuẩn iOS App Archive (Payload/PickleVision.app/)
"""

import os
import sys
import shutil
import zipfile
import plistlib
from pathlib import Path

# Đảm bảo UTF-8 cho stdout trên Windows
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def create_info_plist(version="1.0.0", build="1"):
    return {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": "PickleVision",
        "CFBundleExecutable": "PickleVision",
        "CFBundleIdentifier": "com.picklevision.app",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "PickleVision",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "CFBundleSupportedPlatforms": ["iPhoneOS"],
        "DTPlatformName": "iphoneos",
        "DTPlatformVersion": "17.0",
        "DTSDKName": "iphoneos17.0",
        "LSRequiresIPhoneOS": True,
        "MinimumOSVersion": "17.0",
        "UIDeviceFamily": [1, 2], # 1: iPhone, 2: iPad
        "NSCameraUsageDescription": "Ứng dụng cần quyền truy cập Camera để quay video 1080p @ 60/120fps và phân tích trận đấu Pickleball theo thời gian thực.",
        "NSMicrophoneUsageDescription": "Ứng dụng cần quyền ghi âm để thu tiếng bóng nảy và tiếng vợt phục vụ phân tích rally.",
        "NSPhotoLibraryAddUsageDescription": "Ứng dụng cần lưu video thi đấu kèm đồ họa HUD vào thư viện ảnh của bạn.",
        "NSPhotoLibraryUsageDescription": "Ứng dụng cần quyền đọc thư viện ảnh để xem lại các clip VAR pha bóng tranh chấp.",
        "UIRequiredDeviceCapabilities": ["arm64"],
        "UISupportedInterfaceOrientations": [
            "UIInterfaceOrientationLandscapeRight",
            "UIInterfaceOrientationLandscapeLeft"
        ],
        "UISupportedInterfaceOrientations~ipad": [
            "UIInterfaceOrientationLandscapeRight",
            "UIInterfaceOrientationLandscapeLeft"
        ],
        "UIRequiresFullScreen": True,
        "UIViewControllerBasedStatusBarAppearance": False
    }

def package_ipa(project_dir, output_dir, version="1.0.0", build="1"):
    project_path = Path(project_dir).resolve()
    output_path = Path(output_dir).resolve()
    
    ipa_filename = f"PickleVision_v{version}.ipa"
    final_ipa_path = output_path / ipa_filename
    
    print(f"[*] Bắt đầu đóng gói bản phát hành iOS: {ipa_filename}")
    print(f"[*] Thư mục dự án: {project_path}")
    print(f"[*] Phiên bản: v{version} (Build {build})")
    
    # Tạo thư mục tạm thời Payload
    temp_dir = project_path / "_build_tmp"
    if temp_dir.exists():
        shutil.rmtree(temp_dir)
        
    payload_dir = temp_dir / "Payload"
    app_dir = payload_dir / "PickleVision.app"
    app_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Ghi tệp Info.plist chuẩn iOS
    info_plist_path = app_dir / "Info.plist"
    plist_data = create_info_plist(version=version, build=build)
    with open(info_plist_path, "wb") as fp:
        plistlib.dump(plist_data, fp)
    print(f" [+] Đã tạo Info.plist chuẩn cho iOS 17+ (v{version})")
    
    # 2. Ghi tệp PkgInfo
    pkg_info_path = app_dir / "PkgInfo"
    with open(pkg_info_path, "wb") as fp:
        fp.write(b"APPL????")
    print(f" [+] Đã tạo PkgInfo")
    
    # 3. Sử dụng tệp binary thực thi Mach-O 64-bit arm64 chuẩn
    bin_source = project_path / "bin" / "PickleVision"
    executable_path = app_dir / "PickleVision"
    if bin_source.exists():
        shutil.copy(bin_source, executable_path)
        print(f" [+] Đã nhúng binary Mach-O arm64 chính thức ({bin_source.stat().st_size:,} bytes)")
    else:
        raise FileNotFoundError(f"Không tìm thấy binary Mach-O chuẩn tại: {bin_source}")
    
    # 4. Sao chép cấu trúc _CodeSignature chuẩn nếu có
    codesig_src = project_path / "bin" / "_CodeSignature"
    if codesig_src.exists():
        shutil.copytree(codesig_src, app_dir / "_CodeSignature", dirs_exist_ok=True)
        print(f" [+] Đã tích hợp cấu trúc _CodeSignature/CodeResources chuẩn")
        
    # 5. Sao chép các tệp mã nguồn Swift, Assets và cấu hình vào bundle
    sources_dest = app_dir / "Sources"
    sources_dest.mkdir(exist_ok=True)
    for folder_name in ["App", "Core", "Models", "UI"]:
        src_folder = project_path / folder_name
        if src_folder.exists():
            shutil.copytree(src_folder, sources_dest / folder_name, dirs_exist_ok=True)
            
    package_swift = project_path / "Package.swift"
    if package_swift.exists():
        shutil.copy(package_swift, app_dir / "Package.swift")
        
    print(f" [+] Đã sao chép các module Swift/SwiftUI vào gói ứng dụng")
    
    # 6. Nén toàn bộ cấu trúc Payload thành file .ipa chuẩn
    print(f"[*] Đang nén tệp zip sang {final_ipa_path}...")
    with zipfile.ZipFile(final_ipa_path, "w", zipfile.ZIP_DEFLATED) as ipa_zip:
        for root, dirs, files in os.walk(temp_dir):
            for file in files:
                file_path = Path(root) / file
                archive_name = file_path.relative_to(temp_dir)
                ipa_zip.write(file_path, archive_name)
                
    # Dọn dẹp thư mục tạm
    shutil.rmtree(temp_dir)
    
    file_size_kb = final_ipa_path.stat().st_size / 1024.0
    print(f"[OK] ĐÓNG GÓI THÀNH CÔNG: {final_ipa_path}")
    print(f"[*] Dung lượng file: {file_size_kb:.2f} KB\n")
    return final_ipa_path

if __name__ == "__main__":
    current_dir = Path(__file__).resolve().parent
    # Xuất ra cả thư mục cha và thư mục dự án
    workspace_dir = current_dir.parent
    
    version = "1.0.0"
    if len(sys.argv) > 1:
        version = sys.argv[1].replace("v", "").strip()
        
    ipa_file = package_ipa(project_dir=current_dir, output_dir=workspace_dir, version=version)
    
    # Sao chép thêm một bản vào thư mục dự án để người dùng dễ tìm
    target_copy = current_dir / ipa_file.name
    shutil.copy(ipa_file, target_copy)
    print(f"[*] Đã lưu thêm 1 bản copy tại: {target_copy}")
