#!/bin/bash

# Path to the application log file
LOG_FILE="/home/ubuntu/app/health.log"

# Query the local web server endpoint to extract the HTTP status code
STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:80)

if [ "$STATUS_CODE" -eq 200 ]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] OK | 200 | Application is healthy" >> "$LOG_FILE"
else
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ALERT | $STATUS_CODE | Application check failed - restarting" >> "$LOG_FILE"
    
    # Trigger automated container stack recovery
    cd /home/ubuntu/app && /usr/local/bin/docker-compose restart web-app
fi
