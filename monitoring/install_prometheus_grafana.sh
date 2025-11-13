#!/bin/bash
# Instala Prometheus, node_exporter (pacote Debian) e Grafana
# e configura o textfile collector para ler /var/lib/node_exporter/unbound.prom

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Este script deve ser executado como root.${NC}"
  echo -e "Use: ${YELLOW}sudo $0${NC}"
  exit 1
fi

echo -e "${BLUE}=== Atualizando repositórios...${NC}"
apt-get update -y

echo -e "${BLUE}=== Instalando Prometheus + node_exporter + Grafana...${NC}"
apt-get install -y prometheus prometheus-node-exporter apt-transport-https software-properties-common wget gnupg2

# Repositório Grafana (oficial)
if [ ! -f /etc/apt/sources.list.d/grafana.list ]; then
  echo -e "${BLUE}=== Adicionando repositório Grafana...${NC}"
  wget -q -O - https://packages.grafana.com/gpg.key | gpg --dearmor -o /usr/share/keyrings/grafana.gpg
  echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" \
    > /etc/apt/sources.list.d/grafana.list
  apt-get update -y
fi

apt-get install -y grafana

echo -e "${BLUE}=== Configurando node_exporter com textfile collector...${NC}"

# Diretório para métricas textfile (unbound_metrics.sh usa este)
mkdir -p /var/lib/node_exporter
chown -R prometheus:prometheus /var/lib/node_exporter || true

# Ajusta argumentos do serviço prometheus-node-exporter
NODE_EXPORTER_DEFAULT="/etc/default/prometheus-node-exporter"

if grep -q "collector.textfile" "$NODE_EXPORTER_DEFAULT" 2>/dev/null; then
  echo -e "${YELLOW}collector.textfile já configurado em $NODE_EXPORTER_DEFAULT.${NC}"
else
  echo -e "${BLUE}Adicionando argumentos do textfile collector em $NODE_EXPORTER_DEFAULT...${NC}"
  cat << 'EOF' > "$NODE_EXPORTER_DEFAULT"
ARGS="--collector.textfile --collector.textfile.directory=/var/lib/node_exporter"
EOF
fi

echo -e "${BLUE}=== Ajustando scrape do Prometheus para node_exporter (localhost:9100)...${NC}"
PROM_CONFIG="/etc/prometheus/prometheus.yml"

# Adiciona job se não existir
if ! grep -q "job_name: 'node_exporter'" "$PROM_CONFIG"; then
  cat << 'EOF' >> "$PROM_CONFIG"

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
fi

echo -e "${BLUE}=== Habilitando e iniciando serviços...${NC}"
systemctl daemon-reload

systemctl enable --now prometheus
systemctl enable --now prometheus-node-exporter
systemctl enable --now grafana-server

sleep 3

echo -e "${GREEN}Instalação concluída.${NC}"
echo -e "Prometheus escutando em: ${BLUE}http://<IP_DO_SERVIDOR>:9090${NC}"
echo -e "node_exporter em:         ${BLUE}http://<IP_DO_SERVIDOR>:9100/metrics${NC}"
echo -e "Grafana em:               ${BLUE}http://<IP_DO_SERVIDOR>:3000${NC} (login padrão: admin / admin)"
echo -e "Certifique-se que o script ${YELLOW}/usr/local/bin/unbound_metrics.sh${NC} está no cron para alimentar as métricas."
