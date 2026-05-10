# Lab 07: Command Injection

## Goal

Understand why shell command construction with untrusted input is dangerous.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab07
```

Target: `http://127.0.0.1:8087`

## Tasks

1. Use the normal ping form.
2. Test command separators only against this local container target.
3. Capture output evidence.
4. Explain why `shell=True` or string concatenation creates risk.
5. Propose a fix: argument arrays, strict allowlist, no shell, timeout and privilege isolation.

## Useful Commands

```bash
curl "http://127.0.0.1:8087/?host=127.0.0.1"
```

## Deliverables

- Normal request evidence
- Vulnerability explanation
- Safe implementation recommendation

