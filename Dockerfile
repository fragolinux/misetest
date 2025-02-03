# Usa come base l'immagine buildpack-deps con Bookworm e curl
FROM buildpack-deps:bookworm-curl

# ------------------------------------------------------------------------------
# Definizione della versione di sysdig (modifica qui per aggiornare la versione)
# ------------------------------------------------------------------------------
ARG SYSDIG_VERSION=0.39.0

# ------------------------------------------------------------------------------
# Installazione di "mise" tramite il metodo consigliato (multipiattaforma)
# ------------------------------------------------------------------------------
RUN curl -f -sSL https://mise.run | sh

# Aggiungi la directory in cui mise è installato al PATH (la directory predefinita è ~/.local/bin)
ENV PATH="/root/.local/bin:$PATH"

# ------------------------------------------------------------------------------
# Copia del file .tool-versions nella home dell'utente (utilizzato da mise)
# ------------------------------------------------------------------------------
COPY .tool-versions /root/.tool-versions

# ------------------------------------------------------------------------------
# Installazione degli strumenti (tranne sysdig) tramite una singola chiamata a "mise install"
# ------------------------------------------------------------------------------
RUN mise install

# ------------------------------------------------------------------------------
# Installazione di sysdig tramite i pacchetti .deb, in base all'architettura.
#
# Per x86_64:
#   - Scarica il pacchetto: https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb
#   - Installa anche il pacchetto "dkms" per soddisfare la dipendenza.
#
# Per aarch64 (arm64):
#   - La procedura di installazione viene saltata, perché il pacchetto tende a fallire la compilazione del modulo kernel.
# ------------------------------------------------------------------------------
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      echo "Installazione di sysdig per x86_64" && \
      curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb -o /tmp/sysdig.deb && \
      apt-get update && apt-get install -y dkms && \
      dpkg -i /tmp/sysdig.deb && apt-get install -f -y && rm /tmp/sysdig.deb; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
      echo "Saltata l'installazione di sysdig su arm64 a causa di problemi noti nella compilazione del modulo kernel"; \
    else \
      echo "Architettura non supportata per sysdig: $(uname -m)" && exit 1; \
    fi

# Comando di default
CMD ["bash"]
