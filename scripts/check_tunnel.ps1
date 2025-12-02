# PowerShell script to check Cloudflare Tunnel status
# Usage: powershell -File scripts\check_tunnel.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Cloudflare Tunnel Status Check" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check if cloudflared container exists
Write-Host "[1/5] Checking Cloudflare Tunnel container..." -ForegroundColor Yellow
docker ps -a --filter "name=n8nInstall_cloudflared" --format "table {{.Names}}`t{{.Status}}`t{{.Image}}"
Write-Host ""

# Check Caddy container
Write-Host "[2/5] Checking Caddy reverse proxy..." -ForegroundColor Yellow
docker ps -a --filter "name=n8nInstall_caddy" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
Write-Host ""

# Check SearXNG container
Write-Host "[3/5] Checking SearXNG container..." -ForegroundColor Yellow
docker ps -a --filter "name=n8nInstall_searxng" --format "table {{.Names}}`t{{.Status}}"
Write-Host ""

# Check tunnel logs (last 30 lines)
Write-Host "[4/5] Cloudflare Tunnel Logs (last 30 lines):" -ForegroundColor Yellow
docker logs n8nInstall_cloudflared --tail 30 2>&1
Write-Host ""

# Check Caddy logs for errors
Write-Host "[5/5] Caddy Logs (last 20 lines):" -ForegroundColor Yellow
docker logs n8nInstall_caddy --tail 20 2>&1
Write-Host ""

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Status Check Complete" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test connectivity:" -ForegroundColor Green
Write-Host "  1. Check if tunnel shows 'connected' in logs above" -ForegroundColor White
Write-Host "  2. Visit: https://searxng.verifymyllcname.com" -ForegroundColor White
Write-Host "  3. Check Cloudflare Dashboard for tunnel health" -ForegroundColor White
Write-Host ""
