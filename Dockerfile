FROM python:3.12-slim AS docs-builder

WORKDIR /workspace

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements-docs.txt mkdocs.yml ./
COPY docs ./docs

RUN pip install -r requirements-docs.txt && \
    mkdocs build --strict

FROM nginxinc/nginx-unprivileged:1.27-alpine

ARG RELEASE_VERSION=dev
ARG VCS_REF=local

LABEL org.opencontainers.image.title="Gia Pha Docs" \
      org.opencontainers.image.description="Release image for the Gia Pha documentation site" \
      org.opencontainers.image.source="https://github.com/phamhungptithcm/gia-pha" \
      org.opencontainers.image.version="${RELEASE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

COPY docker/nginx-docs.conf /etc/nginx/conf.d/default.conf
COPY --from=docs-builder /workspace/site /usr/share/nginx/html

EXPOSE 8080
