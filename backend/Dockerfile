FROM python:3.12-slim
WORKDIR /app
COPY pyproject.toml ./
RUN pip install --no-cache-dir fastapi uvicorn[standard] pydantic-settings httpx python-jose[cryptography] sqlalchemy geoalchemy2 alembic psycopg[binary]
COPY app ./app
COPY migrations ./migrations
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
