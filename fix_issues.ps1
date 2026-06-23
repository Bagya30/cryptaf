$files = Get-ChildItem -Path "lib" -Recurse -File -Filter "*.dart"

foreach ($f in $files) {
    $content = Get-Content $f.FullName
    $modified = $false

    $hasFoundation = $false
    $hasMaterial = $false
    foreach ($l in $content) {
        if ($l -match "package:flutter/foundation.dart") { $hasFoundation = $true }
        if ($l -match "package:flutter/material.dart") { $hasMaterial = $true }
    }

    $newContent = $content | ForEach-Object {
        $line = $_
        
        # Replace print with debugPrint
        if ($line -match "print\(") {
            $line = $line -replace "print\(", "debugPrint("
            $modified = $true
        }
        
        # Unused imports
        if ($f.Name -eq "main.dart" -and $line -match "package:cryptaf/screens/email_verification_screen.dart") { $modified = $true; return }
        if ($f.Name -eq "add_nominee_screen.dart" -and ($line -match "dart:typed_data" -or $line -match "package:file_picker/file_picker.dart")) { $modified = $true; return }
        if ($f.Name -eq "dashboard_screen.dart" -and $line -match "package:cryptaf/widgets/vault_search_delegate.dart") { $modified = $true; return }
        if ($f.Name -eq "document_expiry_screen.dart" -and $line -match "package:cryptaf/widgets/glass_container.dart") { $modified = $true; return }
        if ($f.Name -eq "trash_screen.dart" -and $line -match "package:cryptaf/widgets/glass_container.dart") { $modified = $true; return }
        if ($f.Name -eq "vault_health_screen.dart" -and $line -match "package:url_launcher/url_launcher.dart") { $modified = $true; return }
        if ($f.Name -eq "voice_notes_screen.dart" -and $line -match "package:cryptaf/widgets/gradient_button.dart") { $modified = $true; return }
        if ($f.Name -eq "cloudinary_service.dart" -and $line -match "uploader/uploader_interface.dart") { $modified = $true; return }
        if ($f.Name -eq "firestore_service.dart" -and $line -match "dart:typed_data") { $modified = $true; return }
        if ($f.Name -eq "scan_web.dart" -and $line -match "dart:async") { $modified = $true; return }

        # Unused fields
        if ($f.Name -eq "add_nominee_screen.dart" -and ($line -match "final _cloudinary =" -or $line -match "bool _sentEmailOtp =")) { $modified = $true; return }
        if ($f.Name -eq "file_upload_screen.dart" -and $line -match "int _totalStorageUsed =") { $modified = $true; return }
        if ($f.Name -eq "nominee_portal_screen.dart" -and $line -match "bool _isVerifyingOtp =") { $modified = $true; return }
        
        $line
    }
    
    if ($modified) {
        if (-not $hasFoundation -and -not $hasMaterial) {
            $newContent = @("import 'package:flutter/foundation.dart';") + $newContent
        }
        $newContent | Set-Content $f.FullName -Encoding UTF8
    }
}
