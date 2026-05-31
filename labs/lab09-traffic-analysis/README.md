# Lab 09: Traffic Analysis

## Safety Boundary

Only capture and generate traffic for `127.0.0.1`, `localhost`, and the course Docker services exposed on local ports. Do not capture campus traffic or scan external IPs, domains, or real websites.

## Goal

Capture local traffic and extract evidence from HTTP requests.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab09
```

Target: `http://127.0.0.1:8089`

## Tasks

1. Start a packet capture on loopback.
2. Visit `/`, `/api/status`, and `/beacon?id=101`.
3. Stop capture and open it in Wireshark.
4. Filter HTTP or TCP stream.
5. Record source, destination, method, URI, and User-Agent.
6. Build a small IOC table.

## Useful Commands

```bash
sudo tcpdump -i lo -w pcaps/lab09.pcap tcp port 8089
curl http://127.0.0.1:8089/api/status
curl "http://127.0.0.1:8089/beacon?id=101"
```

## Deliverables

- PCAP file
- Wireshark screenshot
- IOC table
