FROM node:20-bookworm-slim AS functions-deps

WORKDIR /workspace/firebase/functions

COPY firebase/functions/package.json firebase/functions/package-lock.json ./

RUN npm ci

FROM node:20-bookworm-slim

ARG RELEASE_VERSION=dev
ARG VCS_REF=local
ARG FIREBASE_TOOLS_VERSION=15.11.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      git \
      openjdk-17-jre-headless \
      python3 && \
    rm -rf /var/lib/apt/lists/* && \
    npm install --global "firebase-tools@${FIREBASE_TOOLS_VERSION}"

WORKDIR /workspace

COPY firebase.json .firebaserc ./
COPY firebase ./firebase
COPY --from=functions-deps /workspace/firebase/functions/node_modules ./firebase/functions/node_modules

RUN npm --prefix firebase/functions run build

LABEL org.opencontainers.image.title="BeFam Firebase Tooling" \
      org.opencontainers.image.description="Firebase Functions build and deploy tooling image for BeFam" \
      org.opencontainers.image.source="https://github.com/phamhungptithcm/gia-pha" \
      org.opencontainers.image.version="${RELEASE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

CMD ["firebase", "--help"]
