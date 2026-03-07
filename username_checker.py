#!/usr/bin/env python3
"""
Username checker for popular social and streaming platforms.
"""

from __future__ import annotations

import concurrent.futures
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable
from urllib import error, parse, request


USER_AGENT = "Mozilla/5.0 (compatible; UsernameChecker/1.0)"
REQUEST_TIMEOUT_SECONDS = 8
MAX_WORKERS = 16


@dataclass(frozen=True)
class Platform:
    name: str
    url_template: str
    unavailable_statuses: tuple[int, ...] = (200,)
    available_statuses: tuple[int, ...] = (404,)
    invalid_statuses: tuple[int, ...] = (400, 401, 403, 405, 429)


PLATFORMS: tuple[Platform, ...] = (
    Platform("X (Twitter)", "https://x.com/{username}"),
    Platform("Instagram", "https://www.instagram.com/{username}/"),
    Platform("Facebook", "https://www.facebook.com/{username}"),
    Platform("TikTok", "https://www.tiktok.com/@{username}"),
    Platform("YouTube", "https://www.youtube.com/@{username}"),
    Platform("Twitch", "https://www.twitch.tv/{username}"),
    Platform("Kick", "https://kick.com/{username}"),
    Platform("Discord", "https://discord.com/users/{username}"),
    Platform("Reddit", "https://www.reddit.com/user/{username}/"),
    Platform("LinkedIn", "https://www.linkedin.com/in/{username}"),
    Platform("Pinterest", "https://www.pinterest.com/{username}/"),
    Platform("Snapchat", "https://www.snapchat.com/add/{username}"),
    Platform("GitHub", "https://github.com/{username}"),
    Platform("GitLab", "https://gitlab.com/{username}"),
    Platform("Steam", "https://steamcommunity.com/id/{username}"),
    Platform("Roblox", "https://www.roblox.com/user.aspx?username={username}"),
    Platform("SoundCloud", "https://soundcloud.com/{username}"),
    Platform("Spotify", "https://open.spotify.com/user/{username}"),
    Platform("Vimeo", "https://vimeo.com/{username}"),
    Platform("Medium", "https://medium.com/@{username}"),
    Platform("DeviantArt", "https://www.deviantart.com/{username}"),
    Platform("Threads", "https://www.threads.net/@{username}"),
    Platform("OnlyFans", "https://onlyfans.com/{username}"),
    Platform("Patreon", "https://www.patreon.com/{username}"),
    Platform("Tumblr", "https://{username}.tumblr.com"),
)


def parse_usernames(raw: str) -> list[str]:
    tokens = re.split(r"[\s,;]+", raw.strip())
    cleaned = [token.strip().lstrip("@") for token in tokens if token.strip()]

    # Keep insertion order while removing duplicates.
    deduped: dict[str, None] = {}
    for username in cleaned:
        deduped[username] = None

    return list(deduped)


def load_usernames_from_file(file_path: str) -> list[str]:
    content = Path(file_path).read_text(encoding="utf-8")
    return parse_usernames(content)


def classify_status(code: int, platform: Platform) -> str:
    if code in platform.unavailable_statuses:
        return "taken"
    if code in platform.available_statuses:
        return "available"
    if code in platform.invalid_statuses:
        return "unknown"
    if 200 <= code < 300:
        return "taken"
    if code == 404:
        return "available"
    return "unknown"


def check_one(platform: Platform, username: str) -> tuple[str, str, str]:
    quoted = parse.quote(username, safe="._-")
    url = platform.url_template.format(username=quoted)

    req = request.Request(url, headers={"User-Agent": USER_AGENT}, method="GET")
    try:
        with request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
            status = classify_status(resp.status, platform)
            return platform.name, status, url
    except error.HTTPError as exc:
        status = classify_status(exc.code, platform)
        return platform.name, status, url
    except Exception:
        return platform.name, "error", url


def check_username(username: str, platforms: Iterable[Platform]) -> list[tuple[str, str, str]]:
    results: list[tuple[str, str, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(check_one, platform, username) for platform in platforms]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
    return sorted(results, key=lambda item: item[0].lower())


def print_results(username: str, results: list[tuple[str, str, str]]) -> None:
    print(f"\nUsername: {username}")
    print("-" * 79)
    print(f"{'Platform':22} {'Status':10} URL")
    print("-" * 79)
    for platform, status, url in results:
        print(f"{platform:22} {status:10} {url}")


def prompt_for_usernames() -> list[str]:
    print("Enter username(s) separated by comma/space/newline.")
    print("Or type a file path (example: usernames.txt) to load a list from file.")
    raw = input("> ").strip()

    if not raw:
        return []

    maybe_file = Path(raw)
    if maybe_file.exists() and maybe_file.is_file():
        return load_usernames_from_file(raw)

    return parse_usernames(raw)


def main() -> None:
    print("Username Checker - social + streaming platforms")
    usernames = prompt_for_usernames()

    if not usernames:
        print("No usernames provided.")
        return

    print(f"\nChecking {len(usernames)} username(s) on {len(PLATFORMS)} platforms...")
    for username in usernames:
        results = check_username(username, PLATFORMS)
        print_results(username, results)

        taken = sum(1 for _, status, _ in results if status == "taken")
        available = sum(1 for _, status, _ in results if status == "available")
        unknown = sum(1 for _, status, _ in results if status == "unknown")
        errors = sum(1 for _, status, _ in results if status == "error")
        print(f"Summary: taken={taken}, available={available}, unknown={unknown}, error={errors}")


if __name__ == "__main__":
    main()
