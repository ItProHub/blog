# =========================================================
# Hexo 博客镜像：多阶段构建（hexo generate → nginx 托管）
#
# 基础镜像可用 --build-arg 覆盖，国内拉不到 docker.io 时示例：
#   docker build \
#     --build-arg NODE_IMAGE=docker.m.daocloud.io/library/node:20-alpine \
#     --build-arg NGINX_IMAGE=docker.m.daocloud.io/library/nginx:1.27-alpine \
#     -t <registry>/dslr/blog:latest .
# =========================================================
ARG NODE_IMAGE=node:20-alpine
ARG NGINX_IMAGE=nginx:1.27-alpine

# =========================================================
# Stage 1：构建静态站点（Hexo generate）
# =========================================================
FROM ${NODE_IMAGE} AS builder

WORKDIR /src

# 国内 npm 源，构建更快更稳
RUN npm config set registry https://registry.npmmirror.com

# 先装依赖，利用镜像层缓存
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# 再拷贝源码（node_modules / .git 等已在 .dockerignore 中排除）
COPY . .

RUN node node_modules/hexo/bin/hexo generate

# =========================================================
# Stage 2：Nginx 托管（站点根路径为 /blog/，与 _config.yml 的 root 一致）
# =========================================================
FROM ${NGINX_IMAGE}

COPY --from=builder /src/public/ /usr/share/nginx/html/blog/
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD wget -qO- http://127.0.0.1/blog/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
