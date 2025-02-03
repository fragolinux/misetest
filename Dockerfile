# Usa come base l'immagine buildpack-deps con Bookworm e curl
FROM buildpack-deps:bookworm-curl

# Definisci l'argomento TARGETARCH (impostato automaticamente da buildx)
ARG TARGETARCH

# ------------------------------------------------------------------------------
# Installazione di "mise" in base all'architettura
# Modifica l'URL e la versione se necessario.
# ------------------------------------------------------------------------------
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      curl -sSL https://github.com/mise/mise/releases/download/v0.1.0/mise-linux-arm64 -o /usr/local/bin/mise; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
      curl -sSL https://github.com/mise/mise/releases/download/v0.1.0/mise-linux-amd64 -o /usr/local/bin/mise; \
    else \
      echo "Architettura non supportata: $TARGETARCH" && exit 1; \
    fi && chmod +x /usr/local/bin/mise

# ------------------------------------------------------------------------------
# Copia del file .tool-versions nella directory di lavoro
# ------------------------------------------------------------------------------
COPY .tool-versions /root/.tool-versions

# ------------------------------------------------------------------------------
# Installazione degli strumenti (tranne sysdig) tramite un'unica riga di "mise install"
# ------------------------------------------------------------------------------
RUN mise install

# ------------------------------------------------------------------------------
# Installazione di sysdig (non disponibile tramite mise)
# Verrà installato solo su architettura x86_64; per altre architetture l'installazione verrà saltata.
# ------------------------------------------------------------------------------
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      apt-get update && apt-get install -y gnupg lsb-release && \
      curl -s https://s3.amazonaws.com/download.draios.com/DRAIOS-GPG-KEY.public | apt-key add - && \
      echo "deb https://download.draios.com/stable/deb stable-$(lsb_release -cs) main" > /etc/apt/sources.list.d/draios.list && \
      apt-get update && apt-get install -y sysdig=1.19.2; \
    else \
      echo "Installazione di sysdig saltata per architetture non x86_64"; \
    fi

# Comando di default
CMD ["bash"]
