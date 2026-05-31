# Lab 12: Incident Response

## Safety Boundary

Only use this lab against `127.0.0.1`, `localhost`, local evidence files, and the course Docker services exposed on local ports. Do not replace course targets with campus IPs, classmates' machines, public IPs, domains, or real websites.

## Goal

Complete a mini incident response exercise from evidence collection to final report.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab12
```

Targets and evidence:

- Incident service: `http://127.0.0.1:8092`
- Nginx lab: `http://127.0.0.1:8082`
- Evidence: `evidence/incident/`
- Runtime logs: `logs/incident/`, `logs/nginx/`

## Tasks

1. Define incident scope.
2. Collect authentication, web, and application evidence.
3. Build a timeline.
4. Identify likely initial access.
5. Identify affected accounts or paths.
6. Recommend containment.
7. Apply and verify a temporary Nginx containment rule.
8. Recommend long-term hardening.
9. Write an executive summary.

## Useful Commands

```bash
curl "http://127.0.0.1:8092/login?user=admin&password=wrong"
curl http://127.0.0.1:8092/admin/export
find evidence/incident logs -type f -print
```

## Temporary Nginx Containment

This step practices emergency web-server hardening. It is intentionally about a different target than the exam: you are blocking exposed backup and sensitive file paths, not writing rules for SQL injection, XSS, command injection, or uploads.

1. Confirm the exposed backup path:

```bash
curl -i http://127.0.0.1:8082/backup/db-backup.txt
```

2. Back up the current Nginx lab config:

```bash
cp services/nginx-lab/default.conf /tmp/lab12-default.conf.bak
```

3. Edit `services/nginx-lab/default.conf` and replace the exposed `/backup/` location with a temporary deny rule:

```nginx
location /backup/ {
    return 403;
}
```

4. Add a second rule to block common sensitive file extensions:

```nginx
location ~* \.(bak|old|sql|conf|env)$ {
    return 403;
}
```

5. Restart only the Nginx lab service:

```bash
docker compose --profile incident restart nginx-lab
```

6. Verify that the containment works:

```bash
curl -i http://127.0.0.1:8082/backup/db-backup.txt
curl -i http://127.0.0.1:8082/backup/old-config.conf
```

Expected result: HTTP `403 Forbidden`.

7. If Nginx fails to restart, inspect logs and fix the configuration syntax:

```bash
docker logs nginx-lab --tail 50
```

8. Restore the original config after the exercise if you need to run earlier labs again:

```bash
cp /tmp/lab12-default.conf.bak services/nginx-lab/default.conf
docker compose --profile incident restart nginx-lab
```

## Deliverables

- Timeline
- Evidence list
- IOC list
- Containment plan
- Screenshot or copied `curl -i` output showing HTTP 403 for the blocked paths
- Short note explaining why temporary containment is not the same as permanent root-cause remediation
- Final incident report
