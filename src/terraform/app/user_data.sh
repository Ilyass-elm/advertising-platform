#!/bin/bash
# EC2 user_data for Ubuntu 22.04 (Jammy). Render with Terraform's
# templatefile(), passing s3_bucket / s3_key / aws_region.
# Requires: instance IAM role with s3:GetObject on the bucket/key below,
# and a security group allowing inbound 5173.
set -euxo pipefail

cat > /opt/deploy.sh << 'DEPLOY_EOF'
#!/bin/bash
set -euxo pipefail

apt-get update -y
apt-get install -y docker.io unzip awscli
systemctl enable --now docker
usermod -aG docker ubuntu

mkdir -p /opt/app
aws s3 cp s3://${s3_bucket}/${s3_key} /opt/app.zip --region ${aws_region}
unzip -o /opt/${zip_file} -d /opt/app

cd /opt/app/${component}
docker build -t ${image_name} .

docker run -d --name ${container_name} -p ${host_port}:${container_port} --restart unless-stopped ${image_name}
DEPLOY_EOF
chmod +x /opt/deploy.sh

# oneshot + a timer that re-triggers it periodically, rather than Restart=
# on the service itself - Restart= on a Type=oneshot service is rejected on
# some systemd versions (bit us on Amazon Linux 2's systemd 219); a timer
# works the same way everywhere and gives the same "keep checking" behavior.
cat > /etc/systemd/system/app-deploy.service << 'UNIT_EOF'
[Unit]
Description=Deploy ${component} container
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/deploy.sh
UNIT_EOF

cat > /etc/systemd/system/app-deploy.timer << 'TIMER_EOF'
[Unit]
Description=Periodically (re)run app-deploy.service

[Timer]
OnBootSec=0
OnUnitInactiveSec=5min
Unit=app-deploy.service

[Install]
WantedBy=timers.target
TIMER_EOF

systemctl daemon-reload
systemctl enable --now app-deploy.timer