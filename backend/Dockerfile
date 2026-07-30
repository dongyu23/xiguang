# syntax=docker/dockerfile:1
# 多阶段构建：Go 源码在 Docker 内编译，宿主机无需安装 Go。

FROM golang:1.25-alpine AS builder
ARG TARGETARCH=amd64
WORKDIR /src

# 先拷依赖清单，利用层缓存
COPY go.mod go.sum ./
RUN go mod download

# 拷源码（.dockerignore 已排除 .git/bin/tmp 等）
COPY . .

# 静态编译，去掉调试信息缩小体积
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /out/xiguang ./cmd/server

FROM builder AS test
RUN go test ./...

# certs 阶段：用 nginx:alpine（本机已缓存，避免拉 alpine:latest）
FROM nginx:alpine AS certs
RUN apk add --no-cache ca-certificates

FROM scratch
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
WORKDIR /app
COPY --from=builder /out/xiguang /app/xiguang
EXPOSE 8080
ENTRYPOINT ["/app/xiguang"]
