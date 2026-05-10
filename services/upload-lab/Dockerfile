FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir flask werkzeug
COPY app.py /app/app.py
RUN mkdir -p /app/uploads /app/logs
EXPOSE 8080
CMD ["python", "app.py"]

