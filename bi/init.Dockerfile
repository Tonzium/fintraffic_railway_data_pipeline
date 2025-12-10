FROM node:18
ARG WORKSPACE_DIR=/evidence-workspace 

RUN apt-get update && apt-get install -y \
    curl wget nano git xdg-utils dos2unix && \
    npm install -g degit && \
    mkdir -p ${WORKSPACE_DIR} && \
    mkdir -p /evidence-bin && \
    rm -rf /var/lib/apt/lists/*

COPY ./bi/bootstrap-init.sh /evidence-bin/bootstrap-init.sh
RUN dos2unix /evidence-bin/bootstrap-init.sh

WORKDIR ${WORKSPACE_DIR}

CMD [ "bash", "/evidence-bin/bootstrap-init.sh" ]
