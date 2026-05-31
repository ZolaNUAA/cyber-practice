# Lab 10: IDS Alert Analysis

## Safety Boundary

This lab uses local evidence files only. Do not scan, probe, or test campus IPs, classmates' machines, public IPs, domains, or real websites.

## Goal

Read IDS-style JSON alerts and connect them to web activity.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab10
```

Evidence: `evidence/ids/eve.json`

## Tasks

1. Read the alert file.
2. Extract timestamp, source, destination, signature, category, severity, and URL.
3. Group alerts by severity.
4. Decide which alert should be triaged first.
5. Write a short analyst note.

## Useful Commands

```bash
jq . evidence/ids/eve.json
jq -r '[.timestamp,.alert.signature,.alert.severity,.http.url] | @tsv' evidence/ids/eve.json
```

## Deliverables

- Alert summary table
- Triage priority
- Analyst note
