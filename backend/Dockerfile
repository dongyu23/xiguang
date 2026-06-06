ARG TARGETARCH=arm64

FROM scratch

ARG TARGETARCH=arm64
WORKDIR /app
COPY bin/xiguang-linux-${TARGETARCH} /app/xiguang
EXPOSE 8080
ENTRYPOINT ["/app/xiguang"]
