FROM python:3.12-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apk upgrade --no-cache && addgroup -S -g 10001 myaaptha && adduser -S -D -H -u 10001 -G myaaptha -h /app myaaptha

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY src ./src

RUN chown -R myaaptha:myaaptha /app
USER 10001:10001

EXPOSE 8081

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8081/api/v1/health')"

CMD ["uvicorn", "ai_service.main:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8081", "--no-server-header"]
