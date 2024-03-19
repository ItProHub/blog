#!/bin/sh


# 读取由 docker run 命令传递的环境变量
GITHUB_TOKEN=$GITHUB_TOKEN

# 拉取代码到指定目录
git clone https://ItProHub:${GITHUB_TOKEN}@github.com/ItProHub/blog.git /blog

exec hexo server