# Run as Administrator on Windows 10/11 to allow Vega P2P & Browser Share over private Wi-Fi
Write-Host "Configuring Windows Defender Firewall rules for Vega..." -ForegroundColor Cyan

New-NetFirewallRule -DisplayName "Vega Direct TCP (47890)" `
  -Direction Inbound -Protocol TCP -LocalPort 47890 -Action Allow -Profile Private,Domain -ErrorAction SilentlyContinue

New-NetFirewallRule -DisplayName "Vega Browser Portal (8080)" `
  -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow -Profile Private,Domain -ErrorAction SilentlyContinue

New-NetFirewallRule -DisplayName "Vega mDNS Discovery (5353)" `
  -Direction Inbound -Protocol UDP -LocalPort 5353 -Action Allow -Profile Private,Domain -ErrorAction SilentlyContinue

Write-Host "Done! Vega can now discover & transfer files with Android devices on the same Wi-Fi/Hotspot." -ForegroundColor Green
