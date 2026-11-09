FROM python:3.12-alpine3.23

ARG TRIVY_VERSION=0.76.2
RUN apk upgrade --no-cache && apk add --no-cache ca-certificates curl && \
    curl -sfL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
      | tar -xz -C /usr/local/bin trivy

WORKDIR /app
COPY vib/scanner/requirements.txt .
RUN python -m pip install --no-cache-dir --upgrade pip==26.3 \
    && pip install --no-cache-dir -r requirements.txt
COPY vib/scanner/scanner.py ./scanner.py
COPY images/vib-k8s/kubernetes_entrypoint.py ./kubernetes_entrypoint.py

# Upstream VIB requires a Docker daemon before scanning ADDITIONAL_IMAGES.
# Trivy can pull registry images directly, so the Kubernetes adapter removes
# that legacy guard and supplies the cluster inventory through the same input.
RUN sed -i 's/skip_additional = True/skip_additional = False/' /app/scanner.py && \
    addgroup -g 10001 vib && adduser -D -u 10001 -G vib vib && \
    chown -R vib:vib /app

USER 10001:10001
ENTRYPOINT ["python", "/app/kubernetes_entrypoint.py"]

