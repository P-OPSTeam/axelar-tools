ADMIN_USER="admin" \
ADMIN_PASSWORD="putyourpassword" \
GF_USERS_ALLOW_SIGN_UP=false \
PROMETHEUS_CONFIG="./data/prometheus.yml" \
GRAFANA_CONFIG="./data/grafana.ini" \
docker-compose up -d --remove-orphans --build $@