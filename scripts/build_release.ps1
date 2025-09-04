Param(
    [switch]$NoZip,
    [switch]$Msix,
    [string]$OutDir = "dist",
    [string]$CertPath,
    [SecureString]$CertPassword
)

# ملاحظات التوقيع الرقمي MSIX:
# 1) أنشئ شهادة تطوير (مؤقتاً) إن لم تملك شهادة رسمية:
#    New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=JWE" -FriendlyName "JWE POS Dev" -CertStoreLocation Cert:\CurrentUser\My
#    ثم صدّرها إلى ملف PFX:
#    $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=JWE" } | Select-Object -First 1
#    Export-PfxCertificate -Cert $cert -FilePath .\certificates\jwe_pos_dev.pfx -Password (ConvertTo-SecureString -String "StrongPassword123" -Force -AsPlainText)
# 2) حدّث الحقول certificate_path و certificate_password في pubspec.yaml (قسم msix_config) أو مرر القيم هنا.
# 3) نفّذ: flutter pub run msix:create
# 4) للتوقيع اليدوي (بديل msix:create يقوم بالتوقيع إذا وُجدت الشهادة):
#    signtool sign /fd SHA256 /a /f certificates\jwe_pos_dev.pfx /p StrongPassword123 dist\msix\Jwe POS.msix
# 5) لاستخدام توقيع موثوق (لتجنب SmartScreen) استخدم شهادة صادرة من CA معترف بها، أو سجل حساب شركة في Microsoft.

$ErrorActionPreference = "Stop"

Write-Host "== Reading version from pubspec.yaml =="
$versionLine = (Get-Content pubspec.yaml | Select-String -Pattern '^[ ]*version:[ ]*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)').Matches.Value
if (-not $versionLine) { throw "Version field not found in pubspec.yaml" }
$version = $versionLine.Split(':')[1].Trim()
$versionName = $version.Split('+')[0]
Write-Host "Version: $version"

Write-Host "== Cleaning project =="
flutter clean

Write-Host "== Getting packages =="
flutter pub get

Write-Host "== Analyzing code =="
flutter analyze --no-preamble
if ($LASTEXITCODE -ne 0) { throw "Analyze errors" }

Write-Host "== Building Windows Release =="
flutter build windows --release

$releasePath = "build/windows/x64/runner/Release"
if (-not (Test-Path $releasePath)) { throw "Release folder not found: $releasePath" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$bundleDir = Join-Path $OutDir "JwePOS-$versionName"
if (Test-Path $bundleDir) { Remove-Item $bundleDir -Recurse -Force }
Copy-Item $releasePath $bundleDir -Recurse

# ملف README مبسط
$readme = @"
Jwe POS $versionName
===================
تشغيل: شغّل jwe_pos.exe

تحديث: استبدل المجلد كاملاً بإصدار أحدث.

موقع قاعدة البيانات: الآن داخل مجلد AppData (Application Support) في مسار jwe_pos/data/ (تم النقل تلقائياً عند أول تشغيل)
"@
$readme | Out-File (Join-Path $bundleDir README.txt) -Encoding UTF8

if (-not $NoZip) {
    Write-Host "== Creating portable ZIP =="
    $zipPath = Join-Path $OutDir "JwePOS-$versionName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path $bundleDir\* -DestinationPath $zipPath
    Write-Host "Created: $zipPath"
}

if ($Msix) {
    Write-Host "== Creating MSIX =="

    # إذا مرر المستخدم شهادة هنا نُحدّث pubspec.yaml مؤقتاً (اختياري - أبسط هو ضبطها مسبقاً في msix_config)
    if ($CertPath -and (Test-Path $CertPath)) {
        Write-Host "-- Using provided certificate: $CertPath"
    }

    # تحويل كلمة المرور إلى نص عادي فقط عند الحاجة (مثلاً signtool)
    $plainPassword = $null
    if ($CertPassword) {
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CertPassword)
        )
    }

    flutter pub run msix:create
    if ($LASTEXITCODE -ne 0) { throw "MSIX creation failed" }
    Write-Host "MSIX created (check dist/msix or build folder)."
}

Write-Host "Build completed successfully."
