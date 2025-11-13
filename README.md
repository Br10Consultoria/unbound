# 🚀 Instalador Modular do Unbound (Resolver DNS)
### Sem AnaBlock · Sem UFW · Com Tuning Automático · Interativo apenas para blocos IPv4/IPv6

Este repositório contém um instalador totalmente **modular**, **leve**, **profissional**, ideal para ISPs, datacenters e servidores dedicados.

O objetivo:  
> Instalar, configurar e otimizar o **Unbound** como servidor DNS recursivo completo, seguro e performático, com mínima interação humana.

---

# 📦 ARQUITETURA DO PROJETO

O instalador está dividido em 4 módulos independentes:


setup_unbound.sh → Script principal (orquestrador)
install_unbound.sh → Instalação base + estrutura do Unbound
tuning_unbound.sh → Tuning automático (CPU, RAM, slab, cache)
configure_network_blocks.sh → Interativo apenas para IPv4/IPv6 (ACLs)


---

# 🛠 RECURSOS PRINCIPAIS

### ✔ Instala unbound + dnsutils  
### ✔ Gera estrutura limpa em `/etc/unbound/unbound.conf.d/`
### ✔ Baixa e processa root-servers (hyperlocal cache)  
### ✔ Aplica TUNING automático:
- threads  
- caches  
- slabs  
- queries-per-thread  
- parâmetros de segurança  
- TTLs  
- EDNS otimizado  
- Minimização de QNAME  
- Prefetch + Prefetch-Key  
- Ratelimit  

### ✔ Configura ACLs **apenas perguntando os blocos IPv4/IPv6**  
(Seu resolver já nasce pronto para uso pelos clientes)

### ✔ ZERO AnaBlock, ZERO UFW  
Projeto mais limpo, direto e focado no DNS.

### ✔ Compatível com:
- Debian 10/11/12  
- Ubuntu 20.04/22.04/24.04  
- Servidores Físicos, VPS, Proxmox, Bare-Metal, Routers x86  

---

# 📥 INSTALAÇÃO

Clone ou baixe os arquivos deste repositório:

```bash
git clone https://seu-repo-github/unbound-installer.git
cd unbound-installer
chmod +x *.sh

/etc/unbound/unbound.conf
/etc/unbound/unbound.conf.d/21-root-auto-trust-anchor-file.conf
/etc/unbound/unbound.conf.d/31-statisticas.conf
/etc/unbound/unbound.conf.d/41-protocols.conf
/etc/unbound/unbound.conf.d/51-acls-locals.conf
/etc/unbound/unbound.conf.d/52-acls-trusteds.conf   ← Seus blocos de IP
/etc/unbound/unbound.conf.d/59-acls-default-policy.conf
/etc/unbound/unbound.conf.d/61-configs.conf         ← Tuning automático
/etc/unbound/unbound.conf.d/62-listen.conf
/etc/unbound/unbound.conf.d/89-hyperlocal-cache.conf
/etc/unbound/unbound.conf.d/99-remote-control.conf


TESTES AUTOMÁTICOS APÓS INSTALAÇÃO

Ao final do processo, os testes são executados automaticamente:

nslookup www.google.com 127.0.0.1
host www.google.com 127.0.0.1
dig @127.0.0.1 www.google.com

LOGS

Os logs ficam em:

/var/log/unbound_install.log
/var/log/unbound_tuning.log
/var/log/unbound_network_blocks.log

Erros específicos:

/var/log/unbound_install_error.log
/var/log/unbound_tuning_error.log
/var/log/unbound_network_blocks_error.log



🛠 REQUISITOS (o script checa e instala automaticamente)

root/sudo

apt-get

pacotes:

curl

wget

net-tools ou ss

dnsutils

unbound

ca-certificates

systemd

bash

Nenhuma ação manual é necessária.

❓ Problemas comuns
"Porta 53 está em uso"

O script aborta imediatamente para evitar conflito.

Pare o serviço conflitante:
