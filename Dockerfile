# Usa come base l'immagine buildpack-deps con Bookworm e curl
FROM buildpack-deps:bookworm-curl

# ------------------------------------------------------------------------------
# Definizione della versione di sysdig (modifica questo ARG per aggiornare la versione)
# ------------------------------------------------------------------------------
ARG SYSDIG_VERSION=0.39.0

# ------------------------------------------------------------------------------
# Installazione di "mise" tramite il metodo consigliato (multipiattaforma)
# ------------------------------------------------------------------------------
RUN curl -f -sSL https://mise.run | sh

# Aggiungi la directory in cui mise viene installato (default: ~/.local/bin) al PATH
ENV PATH="/root/.local/bin:$PATH"

# Aggiungi il comando per attivare mise nelle shell interattive al file .bashrc
RUN echo 'eval "$(~/.local/bin/mise activate bash)"' >> /root/.bashrc

# ------------------------------------------------------------------------------
# Copia del file .tool-versions in /root (così che mise lo trovi)
# ------------------------------------------------------------------------------
COPY .tool-versions /root/.tool-versions

# Imposta la directory di lavoro a /root
WORKDIR /root

# ------------------------------------------------------------------------------
# Installazione degli strumenti (tranne docker e docker-compose) tramite una singola chiamata a "mise install"
# ------------------------------------------------------------------------------
RUN mise install

# ------------------------------------------------------------------------------
# Installazione di sysdig tramite i pacchetti .deb, in base all'architettura:
#
# - Su x86_64:
#     Scarica ed installa il pacchetto:
#       https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb
#     (installando anche il pacchetto "dkms" per soddisfare le dipendenze)
#
# - Su aarch64 (arm64):
#     Viene tentata l'installazione dal pacchetto:
#       https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-aarch64.deb
#     Se fallisce (ad es. per problemi nella compilazione del modulo kernel), viene stampato un avviso e il build prosegue.
# ------------------------------------------------------------------------------
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      echo "Installing sysdig for x86_64" && \
      curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb -o /tmp/sysdig.deb && \
      apt-get update && apt-get install -y dkms && \
      dpkg -i /tmp/sysdig.deb && apt-get install -f -y && rm /tmp/sysdig.deb; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
      echo "Attempting sysdig installation for arm64" && \
      curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-aarch64.deb -o /tmp/sysdig.deb && \
      apt-get update && apt-get install -y dkms && \
      dpkg -i /tmp/sysdig.deb && apt-get install -f -y && rm /tmp/sysdig.deb || \
      echo "Sysdig installation for arm64 failed, continuing"; \
    else \
      echo "Architecture not supported for sysdig: $(uname -m)" && exit 1; \
    fi

# ------------------------------------------------------------------------------
# Installazione di Docker CLI e Docker Compose (non disponibili tramite mise)
# Scarica e installa il binario ufficiale in base all'architettura:
#
# Per Docker CLI (versione 27.5.1):
#   - x86_64: https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz
#   - arm64:  https://download.docker.com/linux/static/stable/aarch64/docker-27.5.1.tgz
#
# Per Docker Compose (versione 2.32.4):
#   - x86_64: https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64
#   - arm64:  https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-aarch64
# ------------------------------------------------------------------------------
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      echo "Installing Docker CLI for x86_64" && \
      curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-27.5.1.tgz -o /tmp/docker.tgz && \
      tar xzvf /tmp/docker.tgz --strip 1 -C /usr/local/bin docker/docker && \
      rm /tmp/docker.tgz && \
      echo "Installing Docker Compose for x86_64" && \
      curl -fsSL https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && \
      chmod +x /usr/local/bin/docker-compose; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
      echo "Installing Docker CLI for arm64" && \
      curl -fsSL https://download.docker.com/linux/static/stable/aarch64/docker-27.5.1.tgz -o /tmp/docker.tgz && \
      tar xzvf /tmp/docker.tgz --strip 1 -C /usr/local/bin docker/docker && \
      rm /tmp/docker.tgz && \
      echo "Installing Docker Compose for arm64" && \
      curl -fsSL https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-aarch64 -o /usr/local/bin/docker-compose && \
      chmod +x /usr/local/bin/docker-compose; \
    else \
      echo "Architecture not supported for Docker CLI/Compose: $(uname -m)" && exit 1; \
    fi

# ------------------------------------------------------------------------------
# Imposta la shell su bash per i comandi seguenti (necessario per i comandi di attivazione di mise)
# ------------------------------------------------------------------------------
SHELL ["/bin/bash", "-c"]

# ------------------------------------------------------------------------------
# Attivazione non interattiva di mise e test dei tool installati:
#
# 1. Attiva mise in modalità non interattiva:
#       eval "$(mise activate bash --shims)"
#       eval "$(mise activate bash)"
#
# 2. Per ogni tool, stampa un messaggio di test e richiama il comando per visualizzarne la versione.
#    (Per kubectl viene usato "kubectl version --client" per evitare errori con flag non supportati)
# ------------------------------------------------------------------------------
RUN eval "$(mise activate bash --shims)" && \
    eval "$(mise activate bash)" && \
    echo "Testing yq..." && yq --version && \
    echo "Testing kubectl..." && kubectl version --client && \
    echo "Testing kubectx..." && kubectx --version && \
    echo "Testing k9s..." && k9s version && \
    echo "Testing sops..." && sops --version && \
    echo "Testing eksctl..." && eksctl version && \
    echo "Testing aws-cli..." && aws --version && \
    echo "Testing Docker CLI..." && docker --version && \
    echo "Testing Docker Compose..." && docker-compose version && \
    echo "Testing python..." && python --version

# Comando di default: avvia una shell interattiva
CMD ["bash"]
