FROM python:3.12-alpine

RUN apk add --no-cache ca-certificates curl
WORKDIR /app
COPY tib/collector/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY tib/collector/collector.py ./collector.py
COPY images/tib-k8s/patch_urls.py /tmp/patch_urls.py
RUN python /tmp/patch_urls.py && rm /tmp/patch_urls.py && \
    addgroup -g 10001 tib && adduser -D -u 10001 -G tib tib && chown -R tib:tib /app

USER 10001:10001
ENTRYPOINT ["python", "/app/collector.py"]

