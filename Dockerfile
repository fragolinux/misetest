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
# Installazione degli strumenti (tranne sysdig) tramite un'unica chiamata a "mise install"
# ------------------------------------------------------------------------------
RUN mise install

# ------------------------------------------------------------------------------
# Installazione di sysdig tramite i pacchetti .deb, in base all'architettura:
#   - x86_64: https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb
#   - aarch64: https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-aarch64.deb
#
# Viene installato anche il pacchetto "dkms" per soddisfare le dipendenze di sysdig.
# ------------------------------------------------------------------------------
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-x86_64.deb -o /tmp/sysdig.deb; \
    elif [ "$(uname -m)" = "aarch64" ]; then \
      curl -f -sSL https://github.com/draios/sysdig/releases/download/${SYSDIG_VERSION}/sysdig-${SYSDIG_VERSION}-aarch64.deb -o /tmp/sysdig.deb; \
    else \
      echo "Architettura non supportata per sysdig: $(uname -m)" && exit 1; \
    fi && \
    apt-get update && apt-get install -y dkms && \
    dpkg -i /tmp/sysdig.deb && apt-get install -f -y && rm /tmp/sysdig.deb

# Comando di default
CMD ["bash"]
