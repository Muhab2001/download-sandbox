# Docker Sandbox Scanner

A lightweight, ephemeral, and hardened environment for downloading and scanning suspicious files.

This tool uses **Docker** to create a disposable "jail." It downloads a file, scans it with **ClamAV** and **Yara**, and only lets you keep the file if it passes all security checks. If a threat is detected, the container (and the file) is instantly destroyed.

> [!WARNING]
> I am not a security expert. I made this tool to create a lightweight alternative to dedicated sandbox to use on light and easy-to-use alternative. If you or your work are too important. Please resort to specialized sandbox solutions :)

> [!NOTE]
> If you are using this tool on Linux, I recommend using [gVisor](https://gvisor.dev/) and the `--runtime=runsc` to the `scan` command to prevent possible kernel escape to your own host. MacOS and Windows users already benefit from the linux VM as added security

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (installed and running).
- **Mac/Linux** (Terminal).

## Quick Start

### 1. Setup

Open your terminal in this directory and build the secure image. This also creates the necessary folders for safe files and rules.

```bash
make build

```

### 2. Update Virus Definitions

Before your first scan (and periodically afterwards), download the latest virus signatures. This saves them to a Docker volume so you don't have to re-download them every time.

```bash
make update-db
```

### 3. Scan a File

To download and scan a file, run the following command. Replace the URL with the link to the suspicious file.

```bash
make scan url="https://example.com/suspicious-file.zip"

```

### 4. The Result

- **CLEAN:** The file is copied to the `safe_files/` folder on your computer. The container is destroyed.
- **INFECTED:** The file is **not** copied. The container is destroyed immediately.

---

## ⚙️ Configuration

### Adding Custom Yara Rules

Yara allows you to scan for specific patterns (like malicious strings or byte sequences) that standard antivirus might miss.

1. Find or write `.yar` or `.yara` rule files.
2. Place them inside the `yara_rules/` folder in this directory.
3. The scanner will automatically pick them up on the next run.

### Where are my files?

- **Safe downloads:** Located in the local `safe_files/` directory.
- **Virus Database:** Stored in a Docker volume named `clamav_db` (managed automatically).

---

## 🔒 Security Features

We use several Docker security features to ensure that even if the downloaded file is malware that tries to execute, it cannot escape the container:

1. **Ephemeral (`--rm`):** The container is destroyed the moment the scan finishes. Nothing persists.
2. **Read-Only Filesystem:** The malware cannot install itself or modify system files. We only allow writing to temporary memory (`tmpfs`).
3. **Non-Root User:** The process runs as `sandboxuser` (UID 10001), not Root.
4. **Cap Drop (`--cap-drop=ALL`):** We strip the container of all Linux kernel capabilities (like changing network settings or mounting drives).
5. **No New Privileges:** Prevents the process from escalating privileges (e.g., using `sudo`).

---

## 🛠️ Troubleshooting

**"ClamAV Database is empty!"**
You skipped Step 2. Run `make update-db` to fetch the virus definitions.

**"Download failed!"**
Check if the URL is correct and accessible. Note that the container has internet access to download the file, but it cannot access your local network.

**Cleaning Up**
To remove the Docker image and the virus definition volume to free up space:

```bash
make clean

```

---

## Disclaimer

This tool provides a strong layer of defense compared to direct installs to host device, but no sandbox is 100% inescapable. Always exercise caution when dealing with suspicious URLs. This tool is provided "as is" without warranty of any kind.
