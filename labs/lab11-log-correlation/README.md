# Lab 11: Log Correlation

## Safety Boundary

Only generate and analyze activity for `127.0.0.1`, `localhost`, and the course Docker services exposed on local ports. Do not replace course targets with campus IPs, classmates' machines, public IPs, domains, or real websites.

## Goal

Correlate web, SSH, and application evidence into a timeline.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab11
```

Evidence directories:

- `logs/nginx/`
- `logs/traffic/`
- `evidence/logs/`

## Tasks

1. Generate web activity against Nginx and traffic lab.
2. Inspect log timestamps.
3. Merge relevant events into a single timeline.
4. Identify normal and suspicious activity.
5. Explain limitations of the available logs.

## Useful Commands

```bash
curl http://127.0.0.1:8082/backup/db-backup.txt
curl "http://127.0.0.1:8089/beacon?id=101"
find logs evidence/logs -type f -maxdepth 3 -print
```

## Deliverables

- Timeline
- Suspicious event list
- Logging gap analysis
