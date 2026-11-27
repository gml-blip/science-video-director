param([switch]$List, [string]$TextFile, [string]$Voice, [string]$Out,
      [string]$Endpoint, [string]$Model = 'Qwen/Qwen3-TTS-12Hz-1.7B-Base',
      [string]$Language = 'Chinese', [int]$Seed = 1729)
$ErrorActionPreference = 'Stop'
if (!$Endpoint) {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
}
try {
    if ($List) {
        $synth.GetInstalledVoices() | Where-Object Enabled | ForEach-Object { $_.VoiceInfo } | Select-Object Name,Culture,Gender
        return
    }
    if (!$TextFile -or !$Out) { throw 'Supply -TextFile and -Out.' }
    $dest = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
    if (Test-Path -LiteralPath $dest) { throw "Output already exists: $dest" }
    $temp = "$dest.$([guid]::NewGuid()).wav"
    $line = (Get-Content -LiteralPath $TextFile -Encoding UTF8 -Raw).Trim()
    if (!$line) { throw 'Empty narration.' }
    if ($Endpoint) {
        if (!$Voice) { throw 'Supply the voice ID from your studio instance.' }
        $body = @{model=$Model;input=$line;voice=$Voice;language=$Language;seed=$Seed;response_format='wav'} | ConvertTo-Json
        Invoke-WebRequest -UseBasicParsing -Uri $Endpoint -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -OutFile $temp -TimeoutSec 300
    } else {
        if ($Voice) { $synth.SelectVoice($Voice) }
        $synth.SetOutputToWaveFile($temp)
        $synth.Speak($line)
        $synth.SetOutputToNull()
    }
    $header = [IO.File]::ReadAllBytes($temp)
    if ($header.Length -le 44 -or [Text.Encoding]::ASCII.GetString($header,0,4) -ne 'RIFF' -or [Text.Encoding]::ASCII.GetString($header,8,4) -ne 'WAVE') { throw 'Invalid WAV response.' }
    [IO.File]::Move($temp,$dest)
} finally {
    if ($synth) { $synth.Dispose() }
    if ($temp -and (Test-Path -LiteralPath $temp)) { Remove-Item -LiteralPath $temp }
}
