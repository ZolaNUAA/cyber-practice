FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server sudo procps vim less \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /run/sshd \
    && useradd -m -s /bin/bash student \
    && echo 'student:Student123' | chpasswd \
    && useradd -m -s /bin/bash dev \
    && echo 'dev:Dev123' | chpasswd \
    && echo 'student ALL=(root) NOPASSWD: /usr/local/bin/show-status' > /etc/sudoers.d/student-status \
    && chmod 0440 /etc/sudoers.d/student-status \
    && printf '#!/bin/sh\nid\nuptime\n' > /usr/local/bin/show-status \
    && chmod 0755 /usr/local/bin/show-status \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]

