# Usa come base l'immagine buildpack-deps con Bookworm e curl
FROM buildpack-deps:bookworm-curl

# ------------------------------------------------------------------------------
# Installazione di "mise" tramite il metodo consigliato (multipiattaforma)
# ------------------------------------------------------------------------------
RUN curl -f -sSL https://mise.run | sh

# Aggiungi la directory in cui mise è installato al PATH
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
# Installazione di sysdig (non gestito tramite mise)
# Viene installato solo su architetture x86_64; per altre architetture l'installazione viene saltata.
# ------------------------------------------------------------------------------
RUN if [ "$(uname -m)" = "x86_64" ]; then \
      apt-get update && apt-get install -y gnupg lsb-release && \
      curl -f -sSL https://s3.amazonaws.com/download.draios.com/DRAIOS-GPG-KEY.public | apt-key add - && \
      echo "deb https://download.draios.com/stable/deb stable-$(lsb_release -cs) main" > /etc/apt/sources.list.d/draios.list && \
      apt-get update && apt-get install -y sysdig=1.19.2; \
    else \
      echo "Installazione di sysdig saltata per architetture non x86_64"; \
    fi

# Comando di default
CMD ["bash"]
