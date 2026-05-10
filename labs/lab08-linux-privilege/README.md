# Lab 08: Linux Privilege and Least Privilege

## Goal

Review Linux permissions, sudo rules, sensitive files, and least privilege.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab08
docker exec -it priv-lab bash
```

Login context is already the low-privilege user `analyst`.

## Tasks

1. Inspect current identity and groups.
2. Review readable files under `/opt`.
3. Review allowed sudo commands with `sudo -l`.
4. Run the allowed backup command.
5. Explain whether the sudo rule is too broad or acceptable.
6. Propose file permission and sudo policy improvements.

## Useful Commands

```bash
id
find /opt -maxdepth 3 -type f -ls
sudo -l
sudo /usr/local/bin/backup-app
```

## Deliverables

- Permission findings
- Sudo rule analysis
- Least privilege recommendations

