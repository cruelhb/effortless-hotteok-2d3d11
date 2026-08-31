# backup.ps1
# 팀별 회식비 데이터를 Firestore에서 내려받아 backups\ 폴더에 저장한다.
#
# 만드는 파일 (실행 시각이 파일명에 붙는다)
#   teams-<날짜시각>.json  복원용. 값이 그대로 들어있다.
#   teams-<날짜시각>.csv   확인용. 엑셀에서 바로 열린다.
#
# 조회 비밀번호가 함께 저장되므로 backups\ 폴더는 git에 올라가지 않도록
# .gitignore 에 등록되어 있다. 외부에 공유하지 말 것.
#
# -NoPause : 끝에서 엔터를 기다리지 않는다. 자동 실행(작업 스케줄러)용.

param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

function Wait-BeforeExit {
    if (-not $NoPause) { Read-Host '엔터를 누르면 닫힙니다' | Out-Null }
}

$projectId  = 'team-dining'
$appId      = 'team-dining-web'
$url        = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/artifacts/$appId/public/data/teams?pageSize=300"

$backupDir  = Join-Path $PSScriptRoot 'backups'
$stamp      = Get-Date -Format 'yyyyMMdd-HHmm'

Write-Host ''
Write-Host '==================================================' -ForegroundColor Green
Write-Host '  팀별 회식비 데이터 백업' -ForegroundColor Green
Write-Host '==================================================' -ForegroundColor Green
Write-Host ''

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

try {
    Write-Host '데이터를 내려받는 중...' -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 60
} catch {
    Write-Host ''
    Write-Host '내려받기 실패:' -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    Write-Host '인터넷 연결을 확인하고 다시 실행해 주세요.' -ForegroundColor Yellow
    Wait-BeforeExit
    exit 1
}

if (-not $response.documents) {
    Write-Host ''
    Write-Host '가져온 팀이 없습니다. 백업 파일을 만들지 않고 종료합니다.' -ForegroundColor Yellow
    Write-Host '(빈 파일로 기존 백업을 덮어쓰는 사고를 막기 위한 동작입니다)' -ForegroundColor Gray
    Wait-BeforeExit
    exit 1
}

# Firestore REST 응답은 값마다 타입이 감싸여 있다. { "carryOver": { "integerValue": "100000" } }
# 이를 평범한 값으로 풀어낸다.
function Get-FirestoreValue($field) {
    if ($null -eq $field) { return $null }
    if ($null -ne $field.integerValue) { return [int64]$field.integerValue }
    if ($null -ne $field.stringValue)  { return [string]$field.stringValue }
    if ($null -ne $field.doubleValue)  { return [double]$field.doubleValue }
    if ($null -ne $field.booleanValue) { return [bool]$field.booleanValue }
    return $null
}

$teams = @()
foreach ($doc in $response.documents) {
    $row = [ordered]@{ docId = ($doc.name -split '/')[-1] }
    foreach ($prop in $doc.fields.PSObject.Properties) {
        $row[$prop.Name] = Get-FirestoreValue $prop.Value
    }
    $teams += [pscustomobject]$row
}

# 화면에 보이는 순서(order)대로 정렬한다.
$teams = $teams | Sort-Object -Property @{ Expression = {
    if ($null -ne $_.order) { $_.order } else { 999999 }
} }

$jsonPath = Join-Path $backupDir "teams-$stamp.json"
$csvPath  = Join-Path $backupDir "teams-$stamp.csv"

$teams | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding utf8

# 엑셀에서 한글이 깨지지 않도록 BOM 포함 UTF-8로 저장한다.
$teams |
    Select-Object name, carryOver, usedAmount, memberCount, perPersonAmount,
                  additionalMemberCount, additionalPerPersonAmount, viewPasscode |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$totalCarry = ($teams | Measure-Object -Property carryOver -Sum).Sum
$totalUsed  = ($teams | Measure-Object -Property usedAmount -Sum).Sum

Write-Host ''
Write-Host "  백업한 팀 수 : $($teams.Count)개" -ForegroundColor Cyan
Write-Host "  이월금 합계  : $('{0:N0}' -f $totalCarry)원" -ForegroundColor Cyan
Write-Host "  사용액 합계  : $('{0:N0}' -f $totalUsed)원" -ForegroundColor Cyan
Write-Host ''
Write-Host '  저장 위치' -ForegroundColor Gray
Write-Host "    $jsonPath" -ForegroundColor Gray
Write-Host "    $csvPath" -ForegroundColor Gray
Write-Host ''

# 오래된 백업 정리: 최근 30개만 남긴다.
$old = Get-ChildItem -Path $backupDir -Filter 'teams-*' |
       Sort-Object LastWriteTime -Descending |
       Select-Object -Skip 60
if ($old) {
    $old | Remove-Item -Force
    Write-Host "  오래된 백업 $($old.Count)개를 정리했습니다. (최근 30회분 유지)" -ForegroundColor DarkGray
    Write-Host ''
}

Write-Host '완료되었습니다.' -ForegroundColor Green
Write-Host ''
Wait-BeforeExit
