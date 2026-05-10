FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir flask
COPY app.py /app/app.py
COPY sample-logs /app/sample-logs
RUN mkdir -p /app/logs
EXPOSE 8080
CMD ["python", "app.py"]

