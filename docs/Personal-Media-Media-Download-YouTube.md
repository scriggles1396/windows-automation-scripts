# YouTube media downloader

Script: [`Personal/Media/Media-Download-YouTube.ps1`](../Personal/Media/Media-Download-YouTube.ps1)

## What it does

Downloads a YouTube video at up to 1080p as an MP4 file, or extracts audio as a 128 kbps MP3.
It can use a shorter, Windows-safe filename or a more original-style filename.

Use it only for content you are allowed to download and use. Platform terms, copyright law, and
the rights holder's permissions can restrict downloading or reuse.

## Requirements

- Windows PowerShell
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [FFmpeg](https://ffmpeg.org/)

The script checks for both required programs before it starts. On Windows, it displays these
package-manager commands if a required program is missing:

```powershell
winget install --id yt-dlp.yt-dlp -e --source winget
winget install --id Gyan.FFmpeg -e --source winget
```

Run the commands separately in PowerShell or Windows Terminal, then close and reopen the terminal
before starting the downloader again. Verify the package name and publisher before installing.

## How to run it

```powershell
.\Media-Download-YouTube.ps1
```

Then:

1. Paste a YouTube URL.
2. Choose `1` for a video up to 1080p or `2` for MP3 audio at 128 kbps.
3. Choose `1` for a short, Windows-safe filename or `2` for an original-style filename.
4. Wait for the success or failure message, then choose whether to download another item.

## Output locations

| Type | Default folder |
| --- | --- |
| Video | Your Windows `Videos\YouTube Videos` folder |
| Audio | Your Windows `Music\YouTube` folder |

The script creates those folders if they do not already exist.

## Common problems

| Problem | What to check |
| --- | --- |
| `yt-dlp could not be found` | Install yt-dlp, then open a new PowerShell window and run the script again. |
| `FFmpeg could not be found` | Install FFmpeg, then open a new PowerShell window and run the script again. |
| Download fails after the tools are found | Read the yt-dlp message above the script's final status. Check the URL, Internet connection, sign-in or content restrictions, and whether yt-dlp needs an update. |
| Video quality is lower than expected | The script requests the best available video at or below 1080p. The source video may not offer a higher-quality stream. |
| Download folder is unavailable | Confirm that the Windows Videos or Music folder exists and that your account can write to it. |
