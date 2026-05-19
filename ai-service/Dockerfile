FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libgl1 libglib2.0-0 curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data/images/products /data/images/rooms /data/images/generated

COPY pyproject.toml /app/
RUN pip install --no-cache-dir -U pip \
    && pip install --no-cache-dir .

COPY . /app

ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

