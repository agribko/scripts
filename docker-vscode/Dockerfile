FROM codercom/code-server:latest

USER root

RUN apt-get update && apt-get install -y \
    maven \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY jdk17.tar.gz /tmp/jdk17.tar.gz
RUN mkdir -p /usr/lib/jvm \
    && tar -xzf /tmp/jdk17.tar.gz -C /usr/lib/jvm \
    && mv /usr/lib/jvm/jdk-17.0.13+11 /usr/lib/jvm/temurin-17 \
    && rm /tmp/jdk17.tar.gz

ENV JAVA_HOME=/usr/lib/jvm/temurin-17
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER coder

RUN code-server --install-extension moocfi.test-my-code; \
    code-server --install-extension vscjava.vscode-java-pack; \
    code-server --install-extension redhat.java; \
    code-server --install-extension vscjava.vscode-java-debug; \
    code-server --install-extension vscjava.vscode-java-test; \
    code-server --install-extension vscjava.vscode-java-dependency; \
    code-server --install-extension vscjava.vscode-maven; \
    code-server --install-extension vscjava.vscode-gradle; \
    code-server --install-extension vscodevim.vim; \
    code-server --install-extension cocopon.iceberg-theme; \
    code-server --install-extension yzane.markdown-pdf; \
    true
