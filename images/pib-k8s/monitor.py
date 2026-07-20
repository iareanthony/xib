import math, os, socket, ssl, time
from datetime import datetime, timezone
import requests
from cryptography import x509

VM=os.getenv("VICTORIAMETRICS_URL","http://xib-victoria-metrics:8428").rstrip("/")
HOSTS=[x.strip() for x in os.getenv("ENDPOINTS",os.getenv("MONITOR_HOSTS","")).split(",") if x.strip()]
INTERVAL=float(os.getenv("CHECK_INTERVAL_HOURS",os.getenv("SCAN_INTERVAL_HOURS","6")))*3600
def inspect(entry):
 host,_,port=entry.partition(":"); port=int(port or 443)
 ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
 with socket.create_connection((host,port),timeout=10) as sock:
  with ctx.wrap_socket(sock,server_hostname=host) as tls: cert=x509.load_der_x509_certificate(tls.getpeercert(True))
 return math.floor((cert.not_valid_after_utc-datetime.now(timezone.utc)).total_seconds()/86400)
def scan():
 stamp=int(time.time()*1000); lines=[]
 for endpoint in HOSTS:
  try: lines.append(f'pib_cert_days_remaining{{host="{endpoint}"}} {inspect(endpoint)} {stamp}')
  except Exception: lines.append(f'pib_cert_probe_success{{host="{endpoint}"}} 0 {stamp}')
 requests.post(f"{VM}/api/v1/import/prometheus",data="\n".join(lines)+"\n",timeout=15).raise_for_status()
if __name__ == "__main__":
 while True: scan(); time.sleep(INTERVAL)
