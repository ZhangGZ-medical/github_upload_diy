# 通过 GitHub REST API 上传本地目录到仓库（沙盒/内网里 git clone/push 走不通时的替代方案）
#
# 用法:
#   $env:GH_TOKEN = 'ghp_xxx'      # 必填，token 不入库、不写进脚本
#   powershell -File upload_via_api.ps1 -Owner ZhangGZ-medical -Repo my-skill -Src 'D:\path\to\skill'
#   powershell -File upload_via_api.ps1 -Owner ... -Repo ... -Src ... -Desensitize 'REAL_SECRET=PLACEHOLDER','REAL_APPID=PLACEHOLDER'
#
# 要点:
#   1. 空仓库也能用（Contents API 会自动建首个提交）；Git Data API 对空仓库建 blob 会返回 409，别用
#   2. 默认排除 .env / __pycache__ / *.pyc，并对 -Desensitize 映射里的字符串做替换
#   3. 上传后建议核验：GET /repos/{owner}/{repo}/contents/{path} 确认占位符已生效、真实密钥未上传
param(
    [Parameter(Mandatory = $true)][string]$Owner,
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$Src,
    [string]$Description = 'WorkBuddy DIY skill',
    [string[]]$Desensitize = @(),
    [string]$CommitPrefix = 'feat: add'
)

$ErrorActionPreference = 'Continue'
$token = $env:GH_TOKEN
if (-not $token) { throw '请先设置环境变量 GH_TOKEN（勿把 token 写进脚本）' }
$api = 'https://api.github.com'
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'skill-upload' }

function Invoke-GH {
    param([string]$Method, [string]$Uri, [string]$BodyStr)
    try {
        if ($BodyStr) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body ([Text.Encoding]::UTF8.GetBytes($BodyStr)) -ContentType 'application/json' -TimeoutSec 120
        }
        return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -TimeoutSec 120
    } catch {
        Write-Host "  ! $Uri :: $($_.Exception.Message)"
        return $null
    }
}

# 1. 仓库
$info = Invoke-GH 'Get' "$api/repos/$Owner/$Repo"
if (-not $info) {
    $body = (@{ name = $Repo; description = $Description; private = $false; auto_init = $false } | ConvertTo-Json -Compress)
    $info = Invoke-GH 'Post' "$api/user/repos" $body
    if (-not $info) { throw '创建仓库失败' }
    Write-Host "REPO-CREATED $($info.html_url)"
} else {
    Write-Host "REPO-EXISTS  $($info.html_url)"
}
$branch = if ($info.default_branch) { $info.default_branch } else { 'main' }

# 2. 本地文件（脱敏后逐个上传）
$pairs = @()
foreach ($d in $Desensitize) {
    if ($d -match '=') { $kv = $d -split '=', 2; $pairs += , @($kv[0].Trim(), $kv[1].Trim()) }
}
$files = Get-ChildItem $Src -Recurse -File | Where-Object {
    $_.Name -ne '.env' -and $_.FullName -notmatch '__pycache__' -and $_.Extension -ne '.pyc' -and $_.Name -ne '.DS_Store'
}
$ok = 0; $fail = 0
foreach ($f in $files) {
    $rel = $f.FullName.Substring($Src.Length + 1).Replace('\', '/')
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    if ($pairs.Count -gt 0 -and $f.Extension -in @('.md', '.py', '.sh', '.txt', '.json', '.ps1')) {
        $txt = [Text.Encoding]::UTF8.GetString($bytes)
        $orig = $txt
        foreach ($p in $pairs) { $txt = $txt.Replace($p[0], $p[1]) }
        if ($txt -ne $orig) { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($txt); Write-Host "  desensitized: $rel" }
    }
    $enc = ($rel -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $uri = "$api/repos/$Owner/$Repo/contents/$enc"
    $cur = Invoke-GH 'Get' "$uri`?ref=$branch"
    $b64 = [Convert]::ToBase64String($bytes)
    $m = ("$CommitPrefix $rel") | ConvertTo-Json
    $bodyStr = '{"message":' + $m + ',"content":"' + $b64 + '","branch":"' + $branch + '"'
    if ($cur) { $bodyStr += ',"sha":"' + $cur.sha + '"' }
    $bodyStr += '}'
    $r = Invoke-GH 'Put' $uri $bodyStr
    if ($r) { $ok++; Write-Host "UPLOADED  $rel" } else { $fail++; Write-Host "FAILED    $rel" }
}
Write-Host "DONE uploaded=$ok failed=$fail"
Write-Host "URL https://github.com/$Owner/$Repo"
