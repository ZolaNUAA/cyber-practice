# Lab 02: Web Information Leakage

## Goal

Find exposed backup/configuration files and propose web server hardening.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab02
```

## Tasks

1. Visit `http://127.0.0.1:8082`.
2. Inspect linked paths and identify the exposed backup directory.
3. Record leaked file names and risk.
4. Review `logs/nginx/access.log`.
5. Propose an Nginx rule to deny `/backup/`.
6. Explain why exposed backups are dangerous even in staging.

## Useful Commands

```bash
curl http://127.0.0.1:8082/backup/
curl http://127.0.0.1:8082/backup/db-backup.txt
tail -n 20 logs/nginx/access.log
```

## Deliverables

- Exposed paths
- Log evidence
- Risk analysis
- Hardened Nginx rule proposal

