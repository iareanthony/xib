import logging, os, time
from datetime import datetime, timedelta, timezone
import requests
from prometheus_client import Gauge, start_http_server

logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
URL=os.getenv("AUTHENTIK_URL", "http://authentik-server.authentication.svc").rstrip("/")
TOKEN=os.getenv("AUTHENTIK_TOKEN", "")
INTERVAL=int(os.getenv("INTERVAL_SECONDS", os.getenv("SYNC_INTERVAL_SECONDS", "300")))
LOOKBACK=int(os.getenv("LOOKBACK_HOURS", "24"))
SESSION=requests.Session(); SESSION.headers.update({"Authorization":f"Bearer {TOKEN}","Accept":"application/json"})
METRICS={name:Gauge(name, help) for name,help in {
 "iib_users_total":"Authentik users", "iib_users_active":"Active Authentik users",
 "iib_users_superuser":"Authentik superusers", "iib_applications_total":"Authentik applications",
 "iib_providers_total":"Authentik providers", "iib_groups_total":"Authentik groups",
 "iib_collection_success":"Most recent collection succeeded", "iib_last_sync_timestamp_seconds":"Last successful collection"
}.items()}
EVENTS=Gauge("iib_events_total","Authentik events in lookback window",["action","window"])

def api(path, params=None):
 r=SESSION.get(f"{URL}/api/v3/{path.strip('/')}/",params=params,timeout=15); r.raise_for_status(); return r.json()
def count(path, params=None): return int(api(path,{"page_size":1,**(params or {})}).get("pagination",{}).get("count",0))
def collect():
 if not TOKEN: raise RuntimeError("AUTHENTIK_TOKEN is empty")
 since=(datetime.now(timezone.utc)-timedelta(hours=LOOKBACK)).strftime("%Y-%m-%dT%H:%M:%S.000000Z")
 for metric,path,params in [("iib_users_total","core/users",{}),("iib_users_active","core/users",{"is_active":"true"}),("iib_users_superuser","core/users",{"is_superuser":"true"}),("iib_applications_total","core/applications",{}),("iib_providers_total","providers/all",{}),("iib_groups_total","core/groups",{})]: METRICS[metric].set(count(path,params))
 for action in ("login","login_failed","password_set"): EVENTS.labels(action,f"{LOOKBACK}h").set(count("events/events",{"action":action,"created__gte":since}))
 METRICS["iib_last_sync_timestamp_seconds"].set_to_current_time(); METRICS["iib_collection_success"].set(1)
def main():
 start_http_server(int(os.getenv("METRICS_PORT","9108")))
 while True:
  try: collect()
  except Exception: METRICS["iib_collection_success"].set(0); logging.exception("collection failed")
  time.sleep(INTERVAL)
if __name__ == "__main__": main()
