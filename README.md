# Cyber Practice Local Lab

This package builds a one-VM Kali teaching environment for 12 network security practice labs.

Students use Kali tools against local Docker targets bound to `127.0.0.1`.
Do not scan or attack networks outside this local lab.

## Quick Start on Kali

```bash
cd ~/cyber-practice
./install-kali.sh
./check-env.sh
./start-lab.sh lab01
```

Open the matching manual under `labs/`.

## Lab List

| Lab | Topic | Start command |
|---|---|---|
| lab01 | Recon and asset discovery | `./start-lab.sh lab01` |
| lab02 | Web information leakage | `./start-lab.sh lab02` |
| lab03 | Authentication audit | `./start-lab.sh lab03` |
| lab04 | SQL injection | `./start-lab.sh lab04` |
| lab05 | XSS and session security | `./start-lab.sh lab05` |
| lab06 | File upload risk | `./start-lab.sh lab06` |
| lab07 | Command injection | `./start-lab.sh lab07` |
| lab08 | Linux privilege and least privilege | `./start-lab.sh lab08` |
| lab09 | Traffic analysis | `./start-lab.sh lab09` |
| lab10 | IDS alert analysis | `./start-lab.sh lab10` |
| lab11 | Log correlation | `./start-lab.sh lab11` |
| lab12 | Incident response | `./start-lab.sh lab12` |

## Useful URLs

- Nginx lab: http://127.0.0.1:8082
- Upload lab: http://127.0.0.1:8086
- Command lab: http://127.0.0.1:8087
- Traffic lab: http://127.0.0.1:8089
- Incident lab: http://127.0.0.1:8092
- Juice Shop: http://127.0.0.1:3000
- WebGoat: http://127.0.0.1:8080/WebGoat
- SSH lab: `ssh student@127.0.0.1 -p 2222`

## Reset

```bash
./reset-lab.sh lab06
```

The reset command recreates Docker containers and local evidence directories.

