FROM debian:bookworm-slim

ARG DEBIAN_MIRROR=http://mirrors.ustc.edu.cn/debian
RUN sed -i "s|http://deb.debian.org/debian|${DEBIAN_MIRROR}|g; s|http://security.debian.org/debian-security|${DEBIAN_MIRROR}-security|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get update && apt-get install -y --no-install-recommends sudo vim less procps findutils gcc make \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash analyst \
    && echo 'analyst:Analyst123' | chpasswd \
    && mkdir -p /opt/app /opt/backups \
    && echo 'db_password=TrainingOnly-DoNotReuse' > /opt/backups/app.env \
    && chmod 0640 /opt/backups/app.env \
    && chown root:analyst /opt/backups/app.env \
    && printf '#!/bin/sh\n/bin/tar -czf /tmp/app-backup.tgz /opt/app 2>/dev/null\n' > /usr/local/bin/backup-app \
    && chmod 0755 /usr/local/bin/backup-app \
    && echo 'analyst ALL=(root) NOPASSWD: /usr/local/bin/backup-app' > /etc/sudoers.d/analyst-backup \
    && chmod 0440 /etc/sudoers.d/analyst-backup \
    && echo 'Review sudo rules, file permissions, and least privilege.' > /home/analyst/README.txt

USER analyst
WORKDIR /home/analyst
CMD ["/bin/bash"]
