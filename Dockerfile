# syntax=docker/dockerfile:1

ARG GO_VERSION=1.21
ARG REPO=github.com/LiterMC/go-openbmclapi
ARG NPM_DIR=dashboard

FROM node:21 AS WEB_BUILD

ARG NPM_DIR

WORKDIR /web/
COPY ["${NPM_DIR}/package.json", "${NPM_DIR}/package-lock.json", "/web/"]
RUN --mount=type=cache,target=/root/.npm/_cacache \
 npm ci --progress=false || { cat /root/.npm/_logs/*; exit 1; }
COPY ["${NPM_DIR}", "/web/"]
RUN npm run build || { cat /root/.npm/_logs/*; exit 1; }

FROM golang:${GO_VERSION}-alpine AS BUILD

ARG TAG
ARG REPO
ARG NPM_DIR

WORKDIR "/go/src/${REPO}/"

COPY ./go.mod ./go.sum "/go/src/${REPO}/"
RUN go mod download
COPY . "/go/src/${REPO}"
COPY --from=WEB_BUILD "/web/dist" "/go/src/${REPO}/${NPM_DIR}/dist"

RUN --mount=type=cache,target=/root/.cache/go-build \
 CGO_ENABLED=0 go build -v -o "/go/bin/go-openbmclapi" -ldflags="-X 'main.BuildVersion=${TAG}'" "."

FROM alpine:latest

WORKDIR /opt/openbmclapi
COPY ./config.yaml /opt/openbmclapi/config.yaml

COPY --from=BUILD "/go/bin/go-openbmclapi" "/go-openbmclapi"

CMD ["/go-openbmclapi"]
