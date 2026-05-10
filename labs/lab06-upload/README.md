# Lab 06: File Upload Risk

## Goal

Understand upload validation, upload directory exposure, and access log evidence.

## Start

```bash
cd ~/cyber-practice
./reset-lab.sh lab06
```

Target: `http://127.0.0.1:8086`

## Tasks

1. Upload a normal text or image file.
2. Upload a file with an unusual extension such as `.php.txt`.
3. View the upload listing.
4. Inspect `logs/upload/upload.log`.
5. Explain the difference between upload, storage, and execution risk.
6. Propose controls: extension allowlist, content validation, random names, no execution in upload directory.

## Useful Commands

```bash
curl -F "file=@README.md" http://127.0.0.1:8086/upload
tail -n 20 logs/upload/upload.log
```

## Deliverables

- Upload evidence
- Log evidence
- Mitigation checklist

