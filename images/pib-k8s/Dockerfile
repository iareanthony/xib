FROM python:3.12-slim-trixie
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update && apt-get full-upgrade -y && rm -rf /var/lib/apt/lists/*
COPY images/pib-k8s/requirements.txt .
RUN python -m pip install --no-cache-dir --upgrade pip==26.3 \
    && pip install --no-cache-dir --requirement requirements.txt \
    && useradd --system --uid 10001 --no-create-home pib
COPY images/pib-k8s/monitor.py .
USER 10001:10001
ENTRYPOINT ["python", "/app/monitor.py"]
