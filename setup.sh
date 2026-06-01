#!/bin/bash

######################
# Author : Prathmesh-b
######################


set -e

echo "========================================="
echo "1. INSTALLING COMPUTE DEPENDENCIES"
echo "========================================="
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common unzip

# Adding Docker Official Engine Keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker ubuntu

echo "========================================="
echo "2. CONFIGURING RUNTIME LOG ROTATION"
echo "========================================="
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
sudo systemctl restart docker

echo "========================================="
echo "3. WRITING DOCKER COMPOSE MANIFEST"
echo "========================================="
mkdir -p /home/ubuntu/app && cd /home/ubuntu/app

# !!! UPDATE THESE VALUES !!!
cat <<EOF > docker-compose.yml
services:
  web-app:
    image: shisya92learner/mega-project-app:v1
    ports:
      - "80:80"
    environment:
      - DB_HOST=postgresuser.xxxxxx.us-east-1.rds.amazonaws.com
      - DB_USER=usernameofdb
      - DB_PASSWORD=passwordofdbpostgresql
      - DB_NAME=postgres
    restart: always
EOF

sudo docker compose up -d

echo "========================================="
echo "4. ESTABLISHING SELF-HEALING AUTOMATION"
echo "========================================="
cat <<'EOF' > /home/ubuntu/app/health_check.sh
#!/bin/bash
URL="http://localhost:80"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_FILE="/home/ubuntu/app/health.log"

STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 $URL)

if [ "$STATUS_CODE" -eq 200 ]; then
    echo "[$TIMESTAMP] Health check passed: Status $STATUS_CODE" >> $LOG_FILE
else
    echo "[$TIMESTAMP] ALERT: Health check failed (Status $STATUS_CODE). Reviving container..." >> $LOG_FILE
    cd /home/ubuntu/app && /usr/bin/docker compose restart web-app
fi
EOF

chmod +x /home/ubuntu/app/health_check.sh

echo "========================================="
echo "5. CREATING CRON SCHEDULING OPERATIONS"
echo "========================================="
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/ubuntu/app/health_check.sh") | crontab -

echo "========================================="
echo "6. SETTING UP DAILY S3 BACKUPS"
echo "========================================="
cat <<'EOF' > /home/ubuntu/app/backup_logs.sh
#!/bin/bash
BUCKET_NAME="project-logs-prathmesh-2026" # !!! s3BUCKET NAME !!!
TIMESTAMP=$(date "+%Y%m%d-%H%M%S")
cd /home/ubuntu/app/

if [ -f "health.log" ]; then
    aws s3 cp health.log s3://$BUCKET_NAME/health-log-$TIMESTAMP.log
    cat /dev/null > health.log
fi
EOF

chmod +x /home/ubuntu/app/backup_logs.sh
(crontab -l 2>/dev/null; echo "0 0 * * * /home/ubuntu/app/backup_logs.sh") | crontab -

echo "SUCCESS: Deployment completed successfully."
