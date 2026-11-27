# 科普视频导演 · Windows 安装包

在装有 Codex 的 Windows x64 电脑上解压整个包，打开解压目录，运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

安装器在当前用户的 Codex 技能目录准备技能及私有 FFmpeg，从 PyPI 下载约 31 MB 并核对 SHA-256。Windows PowerShell 5.1、System.Drawing 和系统语音引擎由 Windows 提供。安装过程会实际合成一段语音，编码、混合并解码 10 秒测试片。成功后在 Codex 新对话中输入：

> 用 $science-video-director 做一集关于水星的竖屏科普。先给我逐字稿，确认后再配音。根据实际配音给我分镜和开头 10 秒有声试片。

标准流程可用系统已有音色或导入 WAV。可选的 Qwen Studio 接口适合已有部署的团队，需服务地址和该实例的音色 ID。系统配音的语言、性别和音质取决于 Windows 已安装的声音。项目音频和音乐授权由使用者按片提供。

离线安装可在同一命令末尾加 `-FFmpegPath "D:\tools\ffmpeg.exe"`，提供含 libx264、AAC 和音频滤镜的构建。默认安装到 `$env:CODEX_HOME\skills`，未设置时使用当前用户的 `.codex\skills`。已存在同名技能时安装器停止，保留已有版本。
