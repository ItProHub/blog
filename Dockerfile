FROM yyw-registry.cn-hangzhou.cr.aliyuncs.com/nebula/sdk:8.0.0 AS build
WORKDIR /app

# 拷贝项目文件并还原依赖项
COPY . .

# 构建发布版本
RUN dotnet publish "src/SubscriptionAccount/SubscriptionAccount.csproj" -c Release -o /app/publish

# 设置运行时镜像
FROM yyw-registry.cn-hangzhou.cr.aliyuncs.com/nebula/aspnet:8.0.0

WORKDIR /app

# 从构建镜像阶段复制发布的文件到运行时镜像
COPY --from=build /app/publish .

EXPOSE 80

ENTRYPOINT ["dotnet", "SubscriptionAccount.dll"]

