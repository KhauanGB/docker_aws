## Documentação da Atividade AWS - Docker 

###  Introdução

Esta documentação detalha o processo de configuração para o deploy de uma aplicação WordPress utilizando **Docker** em instância **EC2** na AWS. O objetivo é consolidar conhecimentos em **DevSecOps**, boas práticas de utilização de containers, e planejamento da infraestrutura.
---
### **Tecnologias Utilizadas**

Durante a implementação desta arquitetura na AWS, diversas tecnologias e ferramentas foram utilizadas para garantir a eficiência, a segurança e a escalabilidade do sistema. Seguem os principais componentes:

#### **1. AWS**
- **Amazon VPC**: Configuração de redes privadas virtuais para isolamento e segurança.
- **Amazon EC2**: Instâncias de computação para hospedar o WordPress e serviços associados.
- **Amazon EFS**: Sistema de arquivos compartilhado para armazenamento consistente entre instâncias.
- **Amazon RDS**: Banco de dados relacional gerenciado (MySQL) para persistência de dados.
- **Classic Load Balancer**: Distribuição de tráfego para instâncias EC2 em sub-redes privadas.
- **NAT Gateway**: Comunicação segura entre sub-redes privadas e a internet.

#### **1.1. Docker**
- **Docker Engine**: Para containerização do WordPress.
- **Docker Compose**: Automação de deploy e gerenciamento de serviços no ambiente.

#### **1.2. Linux**
- **Amazon Linux 2023**: AMI base para instâncias EC2, escolhida pela otimização com a AWS e suporte nativo.
- **NFS**: Protocolo de sistema de arquivos usado pelo EFS para comunicação entre instâncias.

#### **1.3. Segurança**
- **Security Groups**: Controle de tráfego de entrada e saída para cada componente da arquitetura.
- **Bastion Host**: Instância intermediária para acesso SSH seguro a sub-redes privadas.

#### **1.4. Ferramentas Adicionais**
- **SSH**: Acesso remoto às instâncias EC2.
- **Git**: Controle de versionamento e documentação do projeto.

---

### **2. Planejamento e Configuração da VPC**
  <img src="vpc.png" alt="Mapa de recursos" width="800">

#### **2.1. Criação da VPC**

- **Bloco CIDR:** `10.0.0.0/16`
- **Sub-redes:**
  - **Públicas:**
    - `10.0.1.0/24` (us-east-1a)
    - `10.0.2.0/24` (us-east-1b)
  - **Privadas:**
    - `10.0.3.0/24` (us-east-1a)
    - `10.0.4.0/24` (us-east-1b)

#### **2.2. Configuração dos Gateways e Tabelas de Rotas**

- **Internet Gateway:** Associado à VPC para permitir o acesso externo às sub-redes públicas.
- **NAT Gateway:**
  - Criado em uma sub-rede pública.
  - Associado a um IP Elástico (Elastic IP).
  - Usado para permitir que as sub-redes privadas acessem a internet de forma controlada.
- **Tabelas de Rotas:**
  - **Sub-redes públicas:** Configuradas para rotear tráfego para o Internet Gateway.
  - **Sub-redes privadas:** Configuradas para rotear tráfego para o NAT Gateway.

---

### **3. Configuração Inicial dos Security Groups**

#### **3.1. Bastion Host**

- **Inbound:**
  - Porta **22 (SSH):** Permitir acesso apenas do IP público do administrador.
- **Outbound:**
  - Todo o tráfego permitido.

#### **3.2. EFS**
  <img src="efs.png" alt="EFS" width="800">

- **Inbound:**
  - Porta **2049 (NFS):** Permitir acesso apenas dos Security Groups das instâncias EC2 privadas.
- **Outbound:**
  - Todo o tráfego permitido.

#### **3.3. RDS**

- **Inbound:**
  - Porta **3306 (MySQL/Aurora):** Permitir acesso apenas dos Security Groups das instâncias EC2 privadas.
- **Outbound:**
  - Todo o tráfego permitido.

#### **3.4. Load Balancer**

- **Inbound:**
  - Porta **80 (HTTP):** Permitir acesso de qualquer origem (`0.0.0.0/0`).
  - Porta **443 (HTTPS):** Permitir acesso de qualquer origem (`0.0.0.0/0`).
- **Outbound:**
  - Todo o tráfego permitido para as instâncias EC2 privadas.

---


### **4. Configuração do EFS**

#### **4.1. Elastic File System (EFS)**
- Criado para armazenar arquivos estáticos do WordPress e garantir consistência entre instâncias.

#### **4.2. Configuração dos Mount Targets**
- **Sub-redes privadas:**
  - `10.0.3.0/24` (us-east-1a)
  - `10.0.4.0/24` (us-east-1b)
- **Segurança:** Associado ao Security Group do EFS para controlar acesso.

#### **4.3. Montagem nas EC2**
- Diretório de montagem: `/mnt/efs`
- Comandos:
  ```bash
  sudo mkdir -p /mnt/efs
  sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <EFS_ID>.efs.<REGION>.amazonaws.com:/ /mnt/efs

---

### **5. Configuração das Instâncias EC2**

#### **5.1 Criar instâncias EC2 privadas para hospedar a aplicação WordPress.**
- Associar as instâncias às sub-redes privadas configuradas anteriormente.
- Configurar o **User Data** para automatizar a instalação do Docker, Docker Compose e o deploy do WordPress:
  ```bash
  #!/bin/bash
  sudo yum update -y
  sudo yum install -y docker
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -aG docker ec2-user
  sudo curl -L https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo mkdir /app
  cat <<EOF > /app/docker-compose.yml
  version: '3.3'
  services:
    wordpress:
      image: wordpress
      restart: always
      ports:
        - 80:80
      environment:
        WORDPRESS_DB_HOST: <RDS_ENDPOINT>
        WORDPRESS_DB_USER: <DB_USER>
        WORDPRESS_DB_PASSWORD: <DB_PASSWORD>
        WORDPRESS_DB_NAME: <DB_NAME>
      volumes:
        - /mnt/efs:/var/www/html
  EOF
  cd /app
  sudo docker-compose up -d
#### **5.2. Deploy do WordPress**

- Validar a conectividade entre as instâncias EC2, o banco de dados RDS e o EFS.
- Configurar o DNS do Load Balancer para apontar para as instâncias EC2 privadas.
- Acessar a aplicação WordPress pelo endpoint público do Load Balancer e verificar o funcionamento.

---

### **6. Configuração do Banco de Dados RDS**

#### **6.1. Configurações do RDS MySQL**
- **Tipo de Instância:** `db.t3.micro`
- **Armazenamento:** 20 GiB (General Purpose SSD)
- **Backup:** Retenção de 7 dias
- **Subnet Group:** Associado às sub-redes privadas `10.0.3.0/24` e `10.0.4.0/24`
- **Sem Acesso Público:** Configurado para operar exclusivamente em sub-redes privadas

#### **6.2. Configuração de Segurança**
- **Inbound:**
  - Porta **3306 (MySQL/Aurora):** Permitir acesso apenas dos Security Groups das EC2 privadas.

#### **6.3. Conexão ao RDS**
- **Endpoint:** Usado no arquivo `docker-compose.yml`:
  ```yaml
  environment:
    WORDPRESS_DB_HOST: <RDS_ENDPOINT>
    WORDPRESS_DB_USER: <DB_USER>
    WORDPRESS_DB_PASSWORD: <DB_PASSWORD>
    WORDPRESS_DB_NAME: <DB_NAME>

---

### **7. Configuração do Load Balancer**

#### **7.1. Classic Load Balancer**
- **Tipo:** Classic Load Balancer
- **Listeners:**
  - HTTP (`80`)
  - HTTPS (`443`)
- **Health Checks:**
  - Intervalo de checagem: 30 segundos
  - Threshold de sucesso: 2 checagens consecutivas
  - Timeout: 5 segundos
  - Caminho: `/`

#### **7.2. Sub-redes**
- Associado às sub-redes públicas `10.0.1.0/24` e `10.0.2.0/24`

#### **7.3. Configuração de Segurança**
- **Inbound:**
  - Porta **80 (HTTP):** Permitir acesso de qualquer origem (`0.0.0.0/0`)
  - Porta **443 (HTTPS):** Permitir acesso de qualquer origem (`0.0.0.0/0`)
- **Outbound:**
  - Todo o tráfego permitido para as instâncias EC2 privadas.

#### **7.4. Testes de Validação**

- Verificar o acesso ao painel administrativo do WordPress.
- Testar a persistência de dados ao realizar upload de arquivos e validar a integridade no EFS.
- Validar a escalabilidade e balanceamento de carga utilizando o Auto Scaling Group e o Load Balancer.

---

### **Conclusão**

Este projeto demonstrou a implementação de uma arquitetura altamente escalável e segura na AWS para o deploy de uma aplicação WordPress utilizando Docker. A estrutura foi projetada para atender aos seguintes requisitos:

1. **Escalabilidade**: Configuração de Auto Scaling Group para manter a capacidade do sistema mesmo com aumento de tráfego.
2. **Alta Disponibilidade**: Uso de sub-redes em múltiplas zonas de disponibilidade, integradas ao Classic Load Balancer.
3. **Persistência de Dados**: Banco de dados gerenciado com Amazon RDS e armazenamento compartilhado via Amazon EFS.
4. **Segurança**: Comunicação restrita entre os componentes, utilizando Security Groups e NAT Gateway.
5. **Automatização**: Scripts em User Data para provisionamento inicial das instâncias.

O uso das ferramentas e práticas implementadas neste projeto fortaleceu a compreensão sobre DevSecOps, infraestrutura em nuvem e containerização. Além disso, a arquitetura está preparada para suportar futuras expansões e integrações, garantindo desempenho e confiabilidade para os usuários finais.

