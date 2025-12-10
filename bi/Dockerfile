FROM node:18
ARG WORKSPACE_DIR=/evidence-workspace 

RUN apt-get update && apt-get install -y \
    curl wget nano git xdg-utils dos2unix && \
    npm install -g degit && \
    mkdir -p ${WORKSPACE_DIR} && \
    mkdir -p /evidence-bin && \
    rm -rf /var/lib/apt/lists/*

COPY ./bi/bootstrap.sh /evidence-bin/bootstrap.sh
RUN dos2unix /evidence-bin/bootstrap.sh

# We will also copy the files in ./bi/workspace due to
# being forced to use the Compose Watch.
COPY ./bi/workspace /evidence-workspace

WORKDIR ${WORKSPACE_DIR}

CMD [ "bash", "/evidence-bin/bootstrap.sh" ]