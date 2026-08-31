# serve.ps1
# 이 스크립트는 로컬에서 React ES Module 및 Firebase 기능이 CORS 정책 오류 없이 정상 작동하도록 임시 웹 서버를 띄워줍니다.

$port = 4173
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")

try {
    $listener.Start()
    Write-Host "`n==================================================" -ForegroundColor Green
    Write-Host "  실시간 팀별 회식비 조회 로컬 서버 실행 중!  " -ForegroundColor Green
    Write-Host "  주소: http://127.0.0.1:$port/" -ForegroundColor Cyan
    Write-Host "  서버를 종료하려면 이 창을 닫거나 Ctrl+C를 누르세요." -ForegroundColor Yellow
    Write-Host "==================================================`n" -ForegroundColor Green

    # 기본 브라우저로 실행
    Start-Process "http://127.0.0.1:$port/"

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $path = $request.Url.LocalPath
        if ($path -eq "/") { $path = "/index.html" }
        
        Write-Host "Received request: $($request.HttpMethod) $path" -ForegroundColor Gray
        
        $filePath = Join-Path $PSScriptRoot $path
        if (Test-Path $filePath) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $bytes.Length
            
            Write-Host "File size: $($bytes.Length) bytes, Content-Length set to: $($response.ContentLength64)" -ForegroundColor Gray
            
            # 컨텐츠 타입 설정
            if ($path.EndsWith(".html")) { 
                $response.ContentType = "text/html; charset=utf-8" 
            }
            elseif ($path.EndsWith(".js")) { 
                $response.ContentType = "application/javascript; charset=utf-8" 
            }
            elseif ($path.EndsWith(".css")) { 
                $response.ContentType = "text/css; charset=utf-8" 
            }
            
            if ($request.HttpMethod -ne "HEAD") {
                Write-Host "Writing to OutputStream..." -ForegroundColor Gray
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                Write-Host "Write completed successfully" -ForegroundColor Gray
            } else {
                Write-Host "HEAD request, skipping body write" -ForegroundColor Gray
            }
        } else {
            Write-Host "File not found: $filePath (404)" -ForegroundColor Red
            $response.StatusCode = 404
        }
        $response.Close()
        Write-Host "Response closed`n" -ForegroundColor Gray
    }
} catch {
    Write-Error $_.Exception.ToString()
} finally {
    $listener.Close()
}
