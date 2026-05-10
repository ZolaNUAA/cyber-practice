# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Local Kali-based network security teaching lab with 12 hands-on exercises. Each lab uses Docker containers bound to `127.0.0.1` with specific ports, plus Juice Shop / WebGoat for SQL injection and XSS practice.

## Core Commands

```bash
# Start a lab (maps to Docker Compose profiles)
./start-lab.sh lab01    # recon
./start-lab.sh lab04    # sqli → Juice Shop + WebGoat
./start-lab.sh lab09    # traffic → capture on loopback

# Stop all containers
./stop-lab.sh

# Reset a lab (down + rebuild + copy evidence)
./reset-lab.sh lab04

# Check environment
./check-env.sh

# Install Kali tooling
./install-kali.sh
```

## Lab to Profile/Port Mapping

| Lab | Profile | Target Ports |
|-----|---------|--------------|
| lab01 | recon | 8082, 8086, 2222 |
| lab02 | info-leak | 8082 |
| lab03 | auth | 2222 (ssh) |
| lab04 | sqli | 3000 (Juice Shop), 8080 (WebGoat) |
| lab05 | xss | 3000, 8080 |
| lab06 | upload | 8086 |
| lab07 | cmd | 8087 |
| lab08 | priv | priv-lab container (docker exec) |
| lab09 | traffic | 8089 |
| lab10 | ids | evidence/ids/eve.json |
| lab11 | logs | evidence/logs/ |
| lab12 | incident | 8092 |

## Architecture

- **docker-compose.yml** — defines all services with `profiles` for lazy startup
- **services/** — per-lab Dockerfiles and app code (nginx-lab, upload-lab, cmd-lab, traffic-lab, incident-lab, ssh-lab, priv-lab)
- **labs/** — one README per lab with tasks and deliverables
- **evidence/** — per-lab evidence directories (ids, logs, incident); populated by reset-lab.sh
- **logs/** — runtime log output from containers (nginx, upload, traffic, incident)
- **pcaps/** — packet capture storage for traffic labs
- **reports/** — student submission output

## Lab-Specific Notes

- **lab08 (privilege)**: `docker exec -it priv-lab bash` — no exposed port, must exec into container
- **lab09 (traffic)**: use `sudo tcpdump -i lo -w pcaps/lab09.pcap tcp port 8089`
- **lab10 (IDS)**: analyze `evidence/ids/eve.json` (Suricata/EVE format)
- **lab12 (incident)**: target at 127.0.0.1:8092, evidence in `evidence/incident/`