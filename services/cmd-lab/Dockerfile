FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends iputils-ping dnsutils && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir flask
COPY app.py /app/app.py
EXPOSE 8080
CMD ["python", "app.py"]

