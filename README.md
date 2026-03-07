<div align="center">

# ✦ username-checker

_Check username availability across social + streaming platforms._

</div>

A tiny CLI that checks one or many usernames against popular profile URLs and labels each result as:

- `taken`
- `available`
- `unknown`
- `error`

---

## Minimal usage

### Python

```bash
python3 username_checker.py
```

### PowerShell

```powershell
./username_checker.ps1
```

You can paste usernames directly (`alice bob @charlie`) or provide a file path (`usernames.txt`).

---

## Direct input examples

```powershell
./username_checker.ps1 -InputUsernames "alice, bob, charlie"
./username_checker.ps1 -InputFile "./usernames.txt"
```

```bash
python3 username_checker.py
# then enter usernames or a file path when prompted
```

---

## Status logic

- `200` → `taken`
- `404` → `available`
- `400/401/403/405/429` or ambiguous responses → `unknown`
- timeout/network failure → `error`

---

## Platforms (25)

X (Twitter), Instagram, Facebook, TikTok, YouTube, Twitch, Kick, Discord, Reddit, LinkedIn, Pinterest, Snapchat, GitHub, GitLab, Steam, Roblox, SoundCloud, Spotify, Vimeo, Medium, DeviantArt, Threads, OnlyFans, Patreon, Tumblr.

---

## Notes

- Results are best-effort (rate limits, anti-bot checks, and redirects can affect accuracy).
- Be respectful of platform terms and request limits.
