FROM alpine:latest AS certs
RUN apk add --no-cache ca-certificates

FROM scratch
ARG TARGETARCH=arm64
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
WORKDIR /app
COPY bin/xiguang-linux-${TARGETARCH} /app/xiguang
EXPOSE 8080
ENTRYPOINT ["/app/xiguang"]
