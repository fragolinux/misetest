# Base image
FROM buildpack-deps:bookworm-curl

# --- Build arguments ---
ARG SYSDIG_VERSION=0.39.0

# ------------------------------------------------------------------------------
# (Eseguito come root) Installa Docker tramite i pacchetti ufficiali Debian:
# - Installa apt-transport-https, ca-certificates, curl, gnupg
# - Aggiunge il repository ufficiale di Docker per Debian Bookworm
# - Installa docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin e docker-compose-plugin
# - Pulisce la cache apt
# ------------------------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y apt-transport-https ca-certificates curl gnupg && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# (Eseguito come root) Installa sysdig tramite i pacchetti .deb (con dkms) e pulisce la cache
# ------------------------------------------------------------------------------
RUN set -eux; \
    if [ "$(uname -m)" = "x86_64" ]; then \
       echo "Installing sysdig for x86_64"; \
       curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb -o /tmp/sysdig.deb; \
       apt-get update && apt-get install -y dkms; \
       dpkg -i /tmp/sysdig.deb || true; \
       apt-get install -f -y; \
       rm -f /tmp/sysdig.deb; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
       echo "Attempting sysdig installation for arm64"; \
       curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-aarch64.deb -o /tmp/sysdig.deb; \
       apt-get update && apt-get install -y dkms; \
       dpkg -i /tmp/sysdig.deb || true; \
       apt-get install -f -y; \
       rm -f /tmp/sysdig.deb; \
       echo "Sysdig installation for arm64 failed, continuing"; \
    else \
       echo "Architecture not supported for sysdig: $(uname -m)"; \
       exit 1; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# (Eseguito come root) Installa zsh e crea l'utente non privilegiato "vscode"
# ------------------------------------------------------------------------------
RUN set -eux; \
    apt-get update && apt-get install -y zsh && \
    useradd -m -s /usr/bin/zsh vscode && \
    chown -R vscode:vscode /home/vscode && \
    rm -rf /var/lib/apt/lists/*

# Copia il file .tool-versions nella home di vscode e ne cambia il proprietario
COPY .tool-versions /home/vscode/.tool-versions
RUN chown vscode:vscode /home/vscode/.tool-versions

# ------------------------------------------------------------------------------
# (Sempre come root) Crea uno script di test che mostra le versioni dei tool
# ------------------------------------------------------------------------------
RUN echo '#!/usr/bin/env zsh' > /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing yq..." && yq --version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing kubectl..." && kubectl version --client' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing kubectx..." && kubectx --version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing k9s..." && k9s version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing sops..." && sops --version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing eksctl..." && eksctl version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing aws-cli..." && aws --version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing Docker CLI..." && docker --version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing Docker Compose..." && docker compose version' >> /home/vscode/tool-versions.sh && \
    echo 'echo "################"' >> /home/vscode/tool-versions.sh && \
    echo 'echo "Testing python..." && python --version' >> /home/vscode/tool-versions.sh && \
    chmod +x /home/vscode/tool-versions.sh

# ------------------------------------------------------------------------------
# Ora passa all'utente vscode per le installazioni "user-land"
# ------------------------------------------------------------------------------
# ...
USER vscode
WORKDIR /home/vscode

# --- Installazione di mise (come utente vscode) ---
RUN curl -f -sSL https://mise.run | sh

# Assicurati che ~/.local/bin sia nel PATH per vscode
ENV PATH="/home/vscode/.local/bin:$PATH"

# Aggiungi la riga per attivare mise in modalità zsh nel file .zshrc
RUN echo 'eval "$(~/.local/bin/mise activate zsh)"' >> /home/vscode/.zshrc

# --- Esegui "mise install" (che leggerà /home/vscode/.tool-versions) ---
RUN mise install

# Imposta la shell di default per i RUN successivi a zsh
SHELL ["/usr/bin/zsh", "-c"]

# --- Esegui le due righe di attivazione non interattiva e poi lo script di stampa delle versioni ---
RUN eval "$(mise activate zsh --shims)" && \
    eval "$(mise activate zsh)" && \
    /home/vscode/tool-versions.sh

# Aggiungi nel file .zshrc il comando per eseguire lo script all'avvio della shell interattiva
RUN echo '/home/vscode/tool-versions.sh' >> /home/vscode/.zshrc

# Imposta la shell predefinita all'avvio del container
CMD ["zsh"]
