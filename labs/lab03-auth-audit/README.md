# Lab 03: Authentication Audit

## Safety Boundary

Only use this lab against `127.0.0.1`, `localhost`, and the course Docker services exposed on local ports. Do not replace course targets with campus IPs, classmates' machines, public IPs, domains, or real websites.

## Goal

Understand weak credentials, SSH login evidence, and basic brute-force mitigation.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab03
```

## Tasks

1. Connect to the SSH target: `student / Student123`.
2. Try one failed login and one successful login.
3. Inspect Docker logs for SSH authentication evidence.
4. Identify weak password risk.
5. Propose controls: stronger passwords, disable root login, rate limiting, fail2ban.

## Useful Commands

```bash
ssh student@127.0.0.1 -p 2222
docker logs ssh-lab 2>&1 | tail -n 50
nmap -sV -p 2222 127.0.0.1
```

## Deliverables

- Successful/failed login evidence
- Weak credential risk explanation
- Mitigation checklist
