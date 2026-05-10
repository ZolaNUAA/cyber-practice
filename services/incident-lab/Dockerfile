FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir flask
COPY app.py /app/app.py
COPY evidence /app/evidence
RUN mkdir -p /app/logs /app/uploads
EXPOSE 8080
CMD ["python", "app.py"]

