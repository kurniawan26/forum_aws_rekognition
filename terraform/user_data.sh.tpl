#!/bin/bash
set -euo pipefail
exec > /var/log/user_data.log 2>&1

APP_NAME="${app_name}"
AWS_REGION="${aws_region}"
S3_BUCKET="${s3_bucket}"
DOCKER_IMAGE="${docker_image}"
DOMAIN_NAME="${domain_name}"
APP_DIR="/opt/$APP_NAME"

echo "==> Update system"
apt-get update -y

echo "==> Install Docker"
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

echo "==> Install Nginx, AWS CLI & PostgreSQL"
apt-get install -y nginx awscli curl postgresql postgresql-contrib
systemctl enable nginx

echo "==> Setup PostgreSQL"
systemctl enable postgresql
systemctl start postgresql

# Buat user & database postgres
DB_PASSWORD="${db_password}"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE forum_aws_rekognition_prod OWNER postgres;" || true

# Izinkan koneksi dari localhost dengan password
sed -i "s/^local.*all.*postgres.*peer/local   all             postgres                                md5/" /etc/postgresql/*/main/pg_hba.conf
sed -i "s/^local.*all.*all.*peer/local   all             all                                     md5/" /etc/postgresql/*/main/pg_hba.conf
systemctl reload postgresql

echo "==> Fetch secrets dari SSM Parameter Store"
SECRET_KEY_BASE=$(aws ssm get-parameter \
  --name "/$APP_NAME/SECRET_KEY_BASE" \
  --with-decryption \
  --region $AWS_REGION \
  --query "Parameter.Value" \
  --output text)

DATABASE_URL=$(aws ssm get-parameter \
  --name "/$APP_NAME/DATABASE_URL" \
  --with-decryption \
  --region $AWS_REGION \
  --query "Parameter.Value" \
  --output text)

echo "==> Simpan env file"
mkdir -p $APP_DIR
cat > $APP_DIR/.env <<EOF
PHX_SERVER=true
PORT=4000
PHX_HOST=$DOMAIN_NAME
AWS_REGION=$AWS_REGION
S3_BUCKET_NAME=$S3_BUCKET
SECRET_KEY_BASE=$SECRET_KEY_BASE
DATABASE_URL=$DATABASE_URL
POOL_SIZE=10
EOF
chmod 600 $APP_DIR/.env

echo "==> Konfigurasi Nginx reverse proxy"
# Gunakan <<NGINX (tanpa quotes) agar $DOMAIN_NAME diexpand oleh bash.
# Variabel milik Nginx di-escape dengan \$ agar tidak diexpand.
cat > /etc/nginx/sites-available/$APP_NAME <<NGINX
server {
    listen 80;
    server_name ${DOMAIN_NAME:-_};

    client_max_body_size 20M;

    location /health {
        proxy_pass http://localhost:4000/health;
        access_log off;
    }

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        # Cloudflare menyimpan IP asli client di CF-Connecting-IP
        proxy_set_header X-Real-IP \$http_cf_connecting_ip;
        proxy_set_header X-Forwarded-For \$http_cf_connecting_ip;
        # Cloudflare mengirim X-Forwarded-Proto: https — diteruskan ke Phoenix
        # sehingga force_ssl tahu bahwa koneksi user sudah HTTPS via Cloudflare
        proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto;
        proxy_read_timeout 86400;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo "==> Buat systemd service untuk Docker container"
cat > /etc/systemd/system/$APP_NAME.service <<EOF
[Unit]
Description=Forum AWS Rekognition (Docker)
After=docker.service network-online.target
Requires=docker.service

[Service]
TimeoutStartSec=120
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker stop $APP_NAME
ExecStartPre=-/usr/bin/docker rm $APP_NAME
ExecStartPre=/usr/bin/docker pull $DOCKER_IMAGE
ExecStart=/usr/bin/docker run --rm \
  --name $APP_NAME \
  --env-file $APP_DIR/.env \
  -p 4000:4000 \
  $DOCKER_IMAGE
ExecStop=/usr/bin/docker stop $APP_NAME

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $APP_NAME

echo "==> Jalankan database migrations"
docker pull $DOCKER_IMAGE
docker run --rm \
  --env-file $APP_DIR/.env \
  --network host \
  $DOCKER_IMAGE \
  eval "ForumAwsRekognition.Release.migrate"

systemctl start $APP_NAME

echo "==> Setup selesai! App berjalan di port 4000 via Docker."
