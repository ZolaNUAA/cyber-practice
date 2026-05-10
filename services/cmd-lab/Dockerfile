FROM python:3.11-slim
WORKDIR /app
ARG DEBIAN_MIRROR=http://mirrors.ustc.edu.cn/debian
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
RUN sed -i "s|http://deb.debian.org/debian|${DEBIAN_MIRROR}|g; s|http://security.debian.org/debian-security|${DEBIAN_MIRROR}-security|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get update && apt-get install -y --no-install-recommends iputils-ping dnsutils \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir -i "$PIP_INDEX_URL" flask
COPY app.py /app/app.py
EXPOSE 8080
CMD ["python", "app.py"]
