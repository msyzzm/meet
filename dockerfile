
# syntax=docker/dockerfile:1

ARG NODE_VERSION=20.0.0

FROM node:${NODE_VERSION}-alpine as base

# 安装 pnpm
RUN npm install -g pnpm

WORKDIR /usr/src/app

# 下载依赖作为单独步骤以利用 Docker 缓存
FROM base as deps
RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=pnpm-lock.yaml,target=pnpm-lock.yaml \
    --mount=type=cache,target=/root/.pnpm-store \
    pnpm install --frozen-lockfile

# 构建阶段
FROM base as build
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY . .

# 构建应用
RUN pnpm build

# 生产阶段
FROM base as final

ENV NODE_ENV=production

# 以非 root 用户运行
USER node

# 复制构建产物和依赖
COPY --from=deps --chown=node:node /usr/src/app/node_modules ./node_modules
COPY --from=build --chown=node:node /usr/src/app/.next ./.next
COPY --from=build --chown=node:node /usr/src/app/public ./public
COPY --from=build --chown=node:node /usr/src/app/package.json ./package.json
COPY --from=build --chown=node:node /usr/src/app/next.config.js ./next.config.js

# 暴露端口
EXPOSE 3000

# 启动应用
CMD ["pnpm", "start"]

