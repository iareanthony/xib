FROM python:3.12.11-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY images/pib-k8s/requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt && useradd --system --uid 10001 --no-create-home pib
COPY images/pib-k8s/monitor.py .
USER 10001:10001
ENTRYPOINT ["python", "/app/monitor.py"]
