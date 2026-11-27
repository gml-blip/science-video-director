param([Parameter(Mandatory)][string]$Video, [Parameter(Mandatory)][string]$Narration,
      [Parameter(Mandatory)][string]$Out, [string]$Effect, [double]$EffectAt=0,
      [string]$Music, [double]$MusicAt=0, [ValidateRange(0,2)][double]$MusicGain=0.14)
$ErrorActionPreference = 'Stop'
if ($EffectAt -lt 0 -or $MusicAt -lt 0) { throw 'Cue times must be nonnegative.' }
$ff = Join-Path $PSScriptRoot '../bin/ffmpeg.exe'
# Read the silent MP4 duration before padding the voice track. A finite pad also
# works on FFmpeg builds where -shortest cannot stop an infinite audio filter
# when the video stream is copied.
$probe = & { $ErrorActionPreference = 'Continue'; & $ff -hide_banner -i $Video 2>&1 | Out-String }
if ($probe -notmatch 'Duration:\s*(\d+):(\d+):(\d+\.\d+)') { throw 'Cannot measure video duration.' }
$culture = [Globalization.CultureInfo]::InvariantCulture
$seconds = 3600 * [int]$Matches[1] + 60 * [int]$Matches[2] + [double]::Parse($Matches[3],$culture)
$duration = $seconds.ToString($culture)
$inputs = @('-hide_banner','-loglevel','error','-i',$Video,'-i',$Narration)
$filters = @("[1:a]aresample=48000,apad,atrim=duration=$duration[vo]")
$labels = '[vo]'
$count = 1
foreach ($cue in @(@{file=$Effect; time=$EffectAt; gain=1}, @{file=$Music; time=$MusicAt; gain=$MusicGain})) {
    if (!$cue.file) { continue }
    $count++
    $inputs += @('-i',$cue.file)
    $delay = [int][Math]::Round(1000*$cue.time)
    $gain = $cue.gain.ToString([Globalization.CultureInfo]::InvariantCulture)
    $filters += "[${count}:a]aresample=48000,volume=$gain,adelay=${delay}:all=1[a$count]"
    $labels += "[a$count]"
}
$filters += "${labels}amix=inputs=${count}:duration=first:normalize=0,alimiter=limit=0.95:latency=1[mix]"
if (Test-Path -LiteralPath $Out) { throw "Output already exists: $Out" }
$temp = "$Out.$([guid]::NewGuid()).mp4"
try {
    & $ff @inputs -filter_complex ($filters -join ';') -map '0:v:0' -map '[mix]' -c:v copy -c:a aac -movflags +faststart -n $temp
    if ($LASTEXITCODE) { throw "FFmpeg mix failed ($LASTEXITCODE)." }
    Move-Item -LiteralPath $temp -Destination $Out
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
}
