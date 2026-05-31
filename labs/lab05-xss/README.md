# Lab 05: XSS and Session Security

## Safety Boundary

Only use this lab against `127.0.0.1`, `localhost`, and the course Docker services exposed on local ports. Do not replace course targets with campus IPs, classmates' machines, public IPs, domains, or real websites.

## Goal

Understand XSS impact, cookie attributes, output encoding, and CSP.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab05
```

Targets:

- Juice Shop: `http://127.0.0.1:3000`
- WebGoat: `http://127.0.0.1:8080/WebGoat`

## Tasks

1. Complete the reflected and stored XSS lessons in WebGoat A3.
2. Observe DOM behavior in browser developer tools.
3. Inspect cookies and identify missing security attributes.
4. Explain the difference between input filtering and output encoding.
5. Propose CSP and cookie security settings.

## Deliverables

- XSS evidence screenshot
- Cookie attribute notes
- Defense proposal
