# Lab 01: Recon and Asset Discovery

## Goal

Identify local training services, record exposed ports, and build an asset table.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab01
```

## Tasks

1. Confirm the lab boundary is `127.0.0.1`.
2. Scan the expected local ports: `3000,8080,8082,8086,2222`.
3. Identify service names and versions where possible.
4. Visit the HTTP services in a browser.
5. Create an asset table with port, service, purpose, and risk.

## Useful Commands

```bash
nmap -sV -p 3000,8080,8082,8086,2222 127.0.0.1
curl -I http://127.0.0.1:8082/
ssh student@127.0.0.1 -p 2222
```

## Deliverables

- Asset table
- Scan screenshot or command output
- At least three risk observations
- Lab boundary statement

