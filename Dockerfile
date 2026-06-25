FROM debian:latest
WORKDIR /render

ARG TAILSCALE_VERSION
ENV TAILSCALE_VERSION=$TAILSCALE_VERSION

# Install base dependencies + zsh + spaceship prompt
RUN apt-get -qq update \
  && apt-get -qq install --upgrade -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    netcat-openbsd \
    wget \
    dnsutils \
    zsh \
    git \
    curl \
  > /dev/null \
  && apt-get -qq clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
  && :

# Install Spaceship prompt and zsh plugins
RUN mkdir -p /usr/local/share/zsh/site-functions /opt && \
    git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git /opt/spaceship-prompt && \
    ln -sf /opt/spaceship-prompt/spaceship.zsh /usr/local/share/zsh/site-functions/prompt_spaceship_setup && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /opt/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting /opt/zsh-syntax-highlighting

# Configure .zshrc with Spaceship prompt
RUN echo '# Enable Spaceship prompt' > /root/.zshrc && \
    echo 'SPACESHIP_PROMPT_ORDER=(' >> /root/.zshrc && \
    echo '  user dir host git exec_time line_sep exit_code char' >> /root/.zshrc && \
    echo ')' >> /root/.zshrc && \
    echo 'SPACESHIP_PROMPT_ADD_NEWLINE=false' >> /root/.zshrc && \
    echo 'SPACESHIP_CHAR_SYMBOL="➜ "' >> /root/.zshrc && \
    echo 'SPACESHIP_CHAR_SUFFIX=" "' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo 'autoload -U promptinit && promptinit && prompt spaceship' >> /root/.zshrc && \
    echo '' >> /root/.zshrc && \
    echo '# Plugins' >> /root/.zshrc && \
    echo 'source /opt/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /root/.zshrc && \
    echo 'source /opt/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /root/.zshrc

# Set zsh as default shell
RUN usermod -s /usr/bin/zsh root

RUN echo "+search +short" > /root/.digrc
COPY run-tailscale.sh /render/

COPY install-tailscale.sh /tmp
RUN /tmp/install-tailscale.sh && rm -r /tmp/*

CMD ./run-tailscale.sh
