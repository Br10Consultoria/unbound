#!/bin/bash
# Instala Prometheus, node_exporter e Grafana
# Compatível com unbound_exporter (porta 9167)
# Cria jobs automaticamente no Prometheus

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Este script deve ser executado como root.${NC}"
  exit 1
fi

echo -e "${BLUE}=== Atualizando repositórios...${NC}"
apt-get update -y

echo -e "${BLUE}=== Instalando Prometheus + node_exporter + dependências...${NC}"
apt-get install -y prometheus prometheus-node-exporter \
  apt-transport-https software-properties-common wget gnupg2 curl jq

# ---------- Grafana ----------
if [ ! -f /etc/apt/sources.list.d/grafana.list ]; then
  echo -e "${BLUE}=== Adicionando repositório Grafana...${NC}"
  wget -q -O - https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg
  echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" \
    > /etc/apt/sources.list.d/grafana.list
  apt-get update -y
fi

apt-get install -y grafana

# ---------- Prometheus config ----------
PROM_CONFIG="/etc/prometheus/prometheus.yml"

echo -e "${BLUE}=== Ajustando scrape do Prometheus ===${NC}"

# Job node_exporter
if ! grep -q "job_name: 'node_exporter'" "$PROM_CONFIG"; then
  cat << 'EOF' >> "$PROM_CONFIG"

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
fi

# Job unbound_exporter
if ! grep -q "job_name: 'unbound'" "$PROM_CONFIG"; then
  cat << 'EOF' >> "$PROM_CONFIG"

  - job_name: 'unbound'
    static_configs:
      - targets: ['localhost:9167']
EOF
fi

echo -e "${BLUE}=== Reiniciando serviços ===${NC}"
systemctl daemon-reload
systemctl enable --now prometheus
systemctl enable --now prometheus-node-exporter
systemctl enable --now grafana-server

sleep 5

# ---------- Validação ----------
echo -e "${BLUE}=== Validando target unbound_exporter no Prometheus ===${NC}"
if curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[].labels.job' | grep -q '^unbound$'; then
  echo -e "${GREEN}Target unbound_exporter registrado com sucesso.${NC}"
else
  echo -e "${YELLOW}Aviso: target unbound_exporter ainda não visível.${NC}"
fi

echo
echo -e "${GREEN}Instalação concluída.${NC}"
echo -e "Prometheus:       ${BLUE}http://<IP>:9090${NC}"
echo -e "node_exporter:    ${BLUE}http://<IP>:9100/metrics${NC}"
echo -e "unbound_exporter: ${BLUE}http://<IP>:9167/metrics${NC}"
echo -e "Grafana:          ${BLUE}http://<IP>:3000${NC} (admin / admin)"
