FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iputils-ping && rm -rf /var/lib/apt/lists/*
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
RUN pip install --no-cache-dir -i "$PIP_INDEX_URL" flask werkzeug
COPY app.py /app/app.py
RUN mkdir -p /app/uploads /app/logs && chmod 777 /app/uploads /app/logs
EXPOSE 8080
CMD ["python", "app.py"]
