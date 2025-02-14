# 軽量なalpineイメージを選択
FROM node:22-alpine3.20
ENV NODE_PATH /opt/node_modules
RUN apk update && \
    apk add --no-cache git bash
# zenn-cliのインストール
WORKDIR /work
RUN npm init --yes && \
    npm install -g zenn-cli@latest
# 実際に記事を管理するフォルダを作成
# コンテナとホスト間で共有するフォルダ
WORKDIR /work/zenn_contents