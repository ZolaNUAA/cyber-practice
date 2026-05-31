# Teacher Guide

## Course Boundary

All activities are restricted to the local Kali VM and Docker services bound to `127.0.0.1`.
Students must not scan campus networks, classmates' machines, or Internet hosts.
When demonstrating commands, keep the target literal as `127.0.0.1` or `localhost`.
Do not ask students to substitute a campus IP, public IP, domain name, or network segment.
For class incidents, first collect the student's shell history and screenshots, then confirm whether any command target was outside the local lab boundary.

## VM Release Workflow

1. Install Kali in a VM.
2. Copy this directory to `/home/kali/cyber-practice`.
3. Run `./install-kali.sh`.
4. Run `./check-env.sh`.
5. Start each lab once to pull/build images.
6. Clean temporary files with `./stop-lab.sh`.
7. Take a VM snapshot named `baseline-ready`.
8. Export the VM as OVA.

## Suggested VM Resources

- CPU: 4 cores recommended, 2 minimum
- RAM: 8 GB recommended, 4 GB minimum
- Disk: 60 GB recommended
- Network: NAT only is sufficient
- Do not require bridged networking

## Grading Template

Each lab can use 100 points:

- Operation completion: 20
- Evidence collection: 25
- Technical explanation: 20
- Mitigation or defense: 20
- Report quality: 15

## Class Pattern

- 15-20 minutes: event background and concepts
- 60-80 minutes: hands-on lab
- 20 minutes: evidence review and report writing
- 10 minutes: submit report

## Reset Pattern

Before each class:

```bash
cd ~/cyber-practice
./reset-lab.sh lab04
```

If a student's environment is broken:

```bash
./stop-lab.sh
docker system prune -f
./start-lab.sh lab04
```
