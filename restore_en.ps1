param(
    [string]$PowerToysDir = "",
    [string]$ProjectDir = $PSScriptRoot,
    [switch]$NoRestart
)

if ([string]::IsNullOrEmpty($PowerToysDir)) {
    foreach ($candidate in @("$env:LOCALAPPDATA\PowerToys", "$env:ProgramFiles\PowerToys")) {
        if (Test-Path (Join-Path $candidate "PowerToys.exe")) { $PowerToysDir = $candidate; break }
    }
}
if ([string]::IsNullOrEmpty($PowerToysDir)) {
    throw "Không tìm thấy PowerToys. Hãy chỉ định thư mục cài đặt bằng tham số -PowerToysDir."
}

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$backupDir = Join-Path $ProjectDir "backup"
if (-not (Test-Path $backupDir)) {
    throw "Không tìm thấy thư mục sao lưu gốc: $backupDir"
}

Write-Host "Đang tạm dừng PowerToys..." -ForegroundColor Cyan
$ptProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "PowerToys*" -or ($_.Path -and $_.Path.StartsWith($PowerToysDir, [StringComparison]::OrdinalIgnoreCase))
}
foreach ($p in $ptProcs) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
}
Start-Sleep -Milliseconds 1500

$backupFiles = Get-ChildItem $backupDir -Recurse -File
$restored = 0
foreach ($bf in $backupFiles) {
    $rel = $bf.FullName.Substring($backupDir.Length).TrimStart('\')
    $dst = Join-Path $PowerToysDir $rel
    Copy-Item -Path $bf.FullName -Destination $dst -Force
    $restored++
}

Write-Host "Đã khôi phục thành công $restored tệp gốc (tiếng Anh) cho PowerToys!" -ForegroundColor Green

if (-not $NoRestart) {
    Write-Host "Đang khởi động lại PowerToys..." -ForegroundColor Cyan
    Start-Process -FilePath (Join-Path $PowerToysDir "PowerToys.exe")
}
