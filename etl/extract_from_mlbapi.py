import requests, pandas as pd, time
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor, as_completed

SEASONS = range(2020, 2026)  # 2020–2025 inclusive
MLB = 1
MAX_WORKERS = 12

SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "mlb-splits-csv/2.0"})
TIMEOUT = 20

def jget(url, retries=3, pause=0.5):
    for i in range(retries):
        try:
            r = SESSION.get(url, timeout=TIMEOUT)
            if r.ok:
                return r.json()
        except Exception:
            pass
        time.sleep(pause * (2**i))
    return {}

def teams(season):
    url = f"https://statsapi.mlb.com/api/v1/teams?sportId={MLB}&season={season}"
    return jget(url).get("teams", [])

def active_pitchers_2025():
    team_ids = [t["id"] for t in teams(2025)]
    pitcher_ids = set()
    for tid in team_ids:
        url = f"https://statsapi.mlb.com/api/v1/teams/{tid}/roster?rosterType=active"
        for p in jget(url).get("roster", []):
            if p.get("position", {}).get("abbreviation") == "P":
                pitcher_ids.add(p["person"]["id"])
    return sorted(pitcher_ids)

def pitcher_name(person_id):
    url = f"https://statsapi.mlb.com/api/v1/people/{person_id}"
    people = jget(url).get("people", [])
    return people[0]["fullName"] if people else str(person_id)

def pitcher_game_logs(person_id, season):
    url = (f"https://statsapi.mlb.com/api/v1/people/{person_id}/stats"
           f"?stats=gameLog&group=pitching&season={season}")
    data = jget(url).get("stats", [])
    return (data[0].get("splits", []) if data else [])

def as_float_ip(ip_str):
    if not ip_str or ip_str == "0.0":
        return 0.0
    whole, *rest = ip_str.split(".")
    whole = int(whole)
    frac = int(rest[0]) if rest else 0  # .1 -> 1/3, .2 -> 2/3
    return whole + (frac / 3.0)

def season_schedule_map(season):
    """
    Returns: dict[gamePk] -> (venue_id, venue_name, city, state, gameDate)
    Pulls city/state directly by hydrating venue(location).
    """
    url = (
        f"https://statsapi.mlb.com/api/v1/schedule"
        f"?sportId={MLB}&season={season}&gameType=R,F,D,L,W,A"
        f"&hydrate=venue(location)"
    )
    js = jget(url)
    mapping = {}
    for d in js.get("dates", []):
        for g in d.get("games", []):
            pk = g.get("gamePk")
            if not pk:
                continue
            vobj = (g.get("venue") or {})
            loc = vobj.get("location") or {}
            venue_id = vobj.get("id")
            venue_name = vobj.get("name")
            city = loc.get("city") or ""
            state = loc.get("stateAbbrev") or loc.get("state") or ""
            dt = g.get("gameDate")
            mapping[pk] = (venue_id, venue_name, city, state, dt)
    return mapping

# Build schedule maps for all seasons (once)
SCHED_MAPS = {yr: season_schedule_map(yr) for yr in SEASONS}

def logs_for_pitcher(pid):
    name = pitcher_name(pid)
    out_rows = []
    for yr in SEASONS:
        sched_map = SCHED_MAPS[yr]
        splits = pitcher_game_logs(pid, yr)
        for s in splits:
            stat = s.get("stat", {})
            ip = as_float_ip(stat.get("inningsPitched", "0"))
            if ip == 0:
                continue
            er = stat.get("earnedRuns", 0)
            era_game = (er * 9.0 / ip)
            game_pk = (s.get("game") or {}).get("gamePk")
            if not game_pk:
                continue
            venue_id, park, city, state, dt = sched_map.get(game_pk, (None, None, "", "", None))
            if not (venue_id and park and dt):
                continue
            out_rows.append({
                "pitcher_name": name,
                "season": yr,
                "game_pk": game_pk,
                "game_datetime_utc": dt,
                "park": park,
                "park_city": city,
                "park_state": state,
                "game_era": era_game
            })
    return out_rows

def main():
    pitchers = active_pitchers_2025()
    rows = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = [ex.submit(logs_for_pitcher, pid) for pid in pitchers]
        for fut in tqdm(as_completed(futures), total=len(futures), desc="Pitchers"):
            try:
                rows.extend(fut.result())
            except Exception:
                # Keep going if one pitcher fails
                pass
    df = pd.DataFrame(rows).sort_values(["pitcher_name","game_datetime_utc"])
    df.to_csv("active_pitchers_game_splits_2020_2025.csv", index=False)
    print(
        "Wrote active_pitchers_game_splits_2020_2025.csv",
        f"({len(df):,} rows, {df['pitcher_name'].nunique()} pitchers)"
    )

if __name__ == "__main__":
    main()
