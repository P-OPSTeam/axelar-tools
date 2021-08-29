# Configure your notifier channel :
ALERT_TELEGRAM_BOT_TOKEN="putyourbottokenhere"
ALERT_TELEGRAM_CHAT_ID="putyourchatidhere"

cp data/notifiers/notify.yml.tpl data/notifiers/notify.yml

sed -i "s/TGBOTTOKEN/${ALERT_TELEGRAM_BOT_TOKEN}/g" data/notifiers/notify.yml
sed -i "s/TGCHATID/${ALERT_TELEGRAM_CHAT_ID}/g" data/notifiers/notify.yml

ADMIN_USER="admin" \
ADMIN_PASSWORD="putyourpassword" \
GF_USERS_ALLOW_SIGN_UP=false \
PROMETHEUS_CONFIG="./data/prometheus.yml" \
GRAFANA_CONFIG="./data/grafana.ini" \
docker-compose up -d --remove-orphans --build $@