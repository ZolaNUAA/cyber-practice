# Lab 12: Incident Response

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
7. Recommend long-term hardening.
8. Write an executive summary.

## Useful Commands

```bash
curl "http://127.0.0.1:8092/login?user=admin&password=wrong"
curl http://127.0.0.1:8092/admin/export
find evidence/incident logs -type f -print
```

## Deliverables

- Timeline
- Evidence list
- IOC list
- Containment plan
- Final incident report

