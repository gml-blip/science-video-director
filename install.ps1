param([string]$SkillsDirectory, [string]$FFmpegPath)
$ErrorActionPreference = 'Stop'
if (!$SkillsDirectory) {
    $codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $SkillsDirectory = Join-Path $codexRoot 'skills'
}
$name = 'science-video-director'
$target = Join-Path $SkillsDirectory $name
if (Test-Path -LiteralPath $target) { throw "Skill directory already exists: $target. Original files preserved." }
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Drawing
$stage = Join-Path $SkillsDirectory ('.science-video-install-' + [guid]::NewGuid())
$work = Join-Path ([IO.Path]::GetTempPath()) ('science-video-' + [guid]::NewGuid())
function Remove-InstallTemp([string]$Path, [string]$Parent, [string]$Prefix) {
    if (!(Test-Path -LiteralPath $Path)) { return }
    $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
    if ([IO.Path]::GetDirectoryName($resolved) -ne (Resolve-Path -LiteralPath $Parent).ProviderPath.TrimEnd('\') -or
        !([IO.Path]::GetFileName($resolved)).StartsWith($Prefix)) { throw 'Unexpected temporary directory.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
try {
    New-Item -ItemType Directory -Path $SkillsDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $work | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $stage -Recurse
    $bin = New-Item -ItemType Directory -Path (Join-Path $stage 'bin')
    $ff = Join-Path $bin.FullName 'ffmpeg.exe'
    if ($FFmpegPath) {
        Copy-Item -LiteralPath $FFmpegPath -Destination $ff
    } else {
        if (![Environment]::Is64BitOperatingSystem) { throw 'Default download requires 64-bit Windows.' }
        $wheel = Join-Path $work 'ffmpeg.whl'
        $url = 'https://files.pythonhosted.org/packages/2c/c6/fa760e12a2483469e2bf5058c5faff664acf66cadb4df2ad6205b016a73d/imageio_ffmpeg-0.6.0-py3-none-win_amd64.whl'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $wheel
        if ((Get-FileHash -LiteralPath $wheel -Algorithm SHA256).Hash -ne '02fa47c83703c37df6bfe4896aab339013f62bf02c5ebf2dce6da56af04ffc0a') { throw 'FFmpeg package checksum mismatch.' }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($wheel)
        try {
            $entry = @($archive.Entries | Where-Object FullName -like 'imageio_ffmpeg/binaries/ffmpeg*.exe')
            if ($entry.Count -ne 1) { throw 'Unexpected FFmpeg package layout.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0],$ff)
        } finally { $archive.Dispose() }
    }
    $scriptFile = Join-Path $work 'sample.txt'
    'Voice test.' | Set-Content -Encoding UTF8 -LiteralPath $scriptFile
    $wav = Join-Path $work 'voice.wav'
    & (Join-Path $stage 'scripts/voice.ps1') -TextFile $scriptFile -Out $wav
    $visual = Join-Path $work 'visual.mp4'
    & $ff -v error -f lavfi -i 'testsrc2=size=160x90:rate=24:duration=10' -c:v libx264 -pix_fmt yuv420p $visual
    if ($LASTEXITCODE) { throw 'H.264 encoding test failed.' }
    $preview = Join-Path $work 'preview.mp4'
    & (Join-Path $stage 'scripts/mix.ps1') -Video $visual -Narration $wav -Music $wav -MusicAt 4.267 -Effect $wav -EffectAt 4 -Out $preview
    & $ff -v error -xerror -i $preview -map 0:v:0 -map 0:a:0 -f null -
    if ($LASTEXITCODE) { throw 'Preview decode failed.' }
    [IO.Directory]::Move((Resolve-Path -LiteralPath $stage).ProviderPath,$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($target))
    Write-Output "Installed and verified: $target"
} finally {
    Remove-InstallTemp $work ([IO.Path]::GetTempPath()) 'science-video-'
    Remove-InstallTemp $stage $SkillsDirectory '.science-video-install-'
}
