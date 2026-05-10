FROM python:3.11-slim
WORKDIR /app
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
RUN pip install --no-cache-dir -i "$PIP_INDEX_URL" flask
COPY app.py /app/app.py
COPY evidence /app/evidence
RUN mkdir -p /app/logs /app/uploads
EXPOSE 8080
CMD ["python", "app.py"]
