# Automated Multi-Tier Cloud Deployment with Self-Healing Architecture & Observability

A production-grade, highly secure, and resilient web infrastructure deployed on AWS from first principles. This project demonstrates containerized application management, automated infrastructure recovery via shell automation, tight identity-based security perimeters, and active log stream parsing for real-time operations alerting.

## Architecture Diagram

---

## 

## 🏛️ System Architecture

The infrastructure consists of a multi-tier decoupled system engineered to minimize blast radiuses and enforce stateful security boundaries.


### 1. Network & Data Isolation Layer
* **VPC Layout:** Configured a custom VPC split across dedicated public and private subnets.
* **The Web Tier:** A Python/Flask web engine containerized via **Docker Compose** on an Ubuntu **EC2 Web Server Host**, assigned to the public subnet to ingest external internet traffic.
* **The Data Tier:** An **RDS PostgreSQL Database** deployed securely inside private subnets with zero internet route mapping.
* **Stateful Firewalls:** Enforced least-privilege protection using AWS **Security Groups** instead of broad subnet-level NACLs. The database group (`db-sg`) drops all incoming connections on port 5432 *unless* they explicitly originate from the identity of the web group (`web-sg`).

### 2. Automated Edge-Probing & Self-Healing Loop
* **The Evaluator:** A Linux **Cron Job** executes a custom background automation script (`health_check.sh`) on the host every 5 minutes.
* **Remediation Script:** The script leverages an aggressive local network probe to check site health. If the container or database disconnect throws an HTTP network failure or timeout (`000`), the engine appends an `ALERT` flag to local log files and instantly triggers a `docker compose restart web-app` process. This fixes local daemon crashes in under 3 seconds without operator intervention.

### 3. Observability & Alarm Notification System
* **Log Ingestion:** The native **AWS CloudWatch Agent** tails the local system log file, streaming infrastructure metrics up to an AWS **CloudWatch Log Group** in real time.
* **Pattern Matching:** Built a custom CloudWatch **Metric Filter** targeting the string `ALERT`. When found, it increments a custom metric counter (`AppFailureCount`).
* **Closed-Loop Alerting:** Configured a dual-state **CloudWatch Alarm** mapped to an **Amazon SNS Topic**. Operations teams receive structured emails upon state transitions: an `ALARM` notice when a breach occurs, and an automated `OK` confirmation email the moment the self-healing engine restores system stability.

---

## 🛠️ Engineering Challenges & Real-World Troubleshooting

Building this deployment from scratch highlighted several key cloud-infrastructure integration hurdles:

### 1. Silent SNS Notification Drop via Default SSE
* **Issue:** Application logs streamed smoothly to CloudWatch and alarms triggered red, but email dispatches were dropping silently.
* **Root Cause:** Default Server-Side Encryption (SSE) policies on the SNS topic were restricting the CloudWatch Service Principal from executing `sns:Publish`.
* **Resolution:** Corrected the encryption access control pathways, explicitly authorizing the cloud monitor service principal to clear the message queue.

### 2. Sparse-Data Metric Lockout Loop
* **Issue:** Because the local Bash script was self-healing the Docker container so fast (under 3 seconds), CloudWatch recorded only a single minute slice anomaly before data dropped back to null. The alarm got stuck in an "Insufficient Data" state, freezing the dashboard status.
* **Root Cause:** A sparse data collection pattern without a baseline metric fallback.
* **Resolution:** Refactored the Metric Filter to pass an explicit default value of `0` during clean execution intervals. This forced CloudWatch to draw a continuous evaluation timeline, instantly enabling real-time `ALARM` ➔ `OK` status recoveries.

---

## 📂 Core Automation Script Reference

### Local Container Triage & Recovery Script (`health_check.sh`)
```bash
#!/bin/bash
# Localized edge-probe automation script

LOG_FILE="/home/ubuntu/app/health.log"
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:80)

if [ "$STATUS_CODE" -eq 200 ]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] OK | 200 | Application is healthy" >> "$LOG_FILE"
else
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ALERT | $STATUS_CODE | Application check failed - restarting" >> "$LOG_FILE"
    
    # Automated Remediation Action
    cd /home/ubuntu/app && /usr/local/bin/docker-compose restart web-app
fi
