"""Make upstream TIB feed locations configurable in the XIB adapter image."""

from pathlib import Path

path = Path("/app/collector.py")
source = path.read_text()
old = '''CISA_KEV_URL = "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json"
EPSS_API_URL = "https://api.first.org/data/v1/epss"'''
new = '''CISA_KEV_URL = os.environ.get(
    "CISA_KEV_URL",
    "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json",
)
EPSS_API_URL = os.environ.get("EPSS_API_URL", "https://api.first.org/data/v1/epss")'''
if old not in source:
    raise SystemExit("upstream TIB feed constants changed; update the XIB adapter")
path.write_text(source.replace(old, new))

