# Lab 04: SQL Injection

## Goal

Practice SQL injection in a local teaching target and write professional mitigation advice.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab04
```

Targets:

- Juice Shop: `http://127.0.0.1:3000`
- WebGoat: `http://127.0.0.1:8080/WebGoat`

## Tasks

1. Intercept a login or search request with Burp/ZAP.
2. Follow the built-in SQL injection lesson in WebGoat or Juice Shop.
3. Capture the request and response.
4. Explain where untrusted input reaches a database query.
5. Write a mitigation plan: parameterized queries, least-privileged DB accounts, generic errors.

## Deliverables

- Request/response evidence
- Vulnerable parameter explanation
- Mitigation plan

