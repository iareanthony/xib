FROM python:3.12-alpine3.23

ARG TRIVY_VERSION=0.76.2
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates curl && \
    curl -sfL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
      | tar -xz -C /usr/local/bin trivy

WORKDIR /app
COPY cib/checker/requirements.txt .
RUN python -m pip install --no-cache-dir --upgrade pip==26.3 \
    && pip install --no-cache-dir -r requirements.txt
COPY cib/checker/checker.py ./checker.py
COPY images/cib-k8s/kubernetes_entrypoint.py ./kubernetes_entrypoint.py
RUN addgroup -g 10001 cib && adduser -D -u 10001 -G cib cib && chown -R cib:cib /app

USER 10001:10001
ENTRYPOINT ["python", "/app/kubernetes_entrypoint.py"]

