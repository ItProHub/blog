---
title: Rspack：一个新一代的 JavaScript 打包工具
date: 2024-11-29 15:50:26
tags:
---

在前端开发中，构建工具的选择一直是开发效率和性能优化的关键因素之一。Webpack 一直是前端开发中最流行的构建工具之一，但随着项目越来越复杂和构建时间的增加，开发者们开始寻找性能更强、更轻量的替代品。Rspack 就是应运而生的这样一款工具，它不仅继承了 Webpack 的思想，还通过一系列创新的优化大大提升了构建速度。

在这篇博客中，我们将介绍 Rspack，并通过一些实际示例来展示它相对于传统构建工具的优势。

![background](./images/rspack/bg.png)

# 什么是 Rspack？
Rspack 是一个由 ByteDance 推出的高性能构建工具。它旨在通过使用更先进的技术栈和优化算法，解决 Webpack 在大型项目中的构建性能瓶颈。Rspack 的设计目标是实现“秒级构建”，使开发者能够专注于代码而非等待构建过程。

Rspack 与 Webpack 相似，但其更强大的性能和优化策略，使得它在大型前端应用的构建中尤为适用。Rspack 目前对 ES 模块、TypeScript、React 等前端技术有很好的支持。

# Rspack 的核心特点
1. 更快的构建速度
Rspack 最突出的特点就是其极致的构建速度。相比 Webpack，Rspack 在内存缓存、模块解析、代码拆分等多个方面做了优化，使得它在构建速度上有了显著的提升。

2. 基于 Rust 的高性能编译
Rspack 使用 Rust 语言编写了其核心模块，因此在计算密集型的任务（例如文件打包和模块解析）上，比 JavaScript 实现要快得多。Rust 本身的高性能特性使得 Rspack 在构建过程中能够更高效地处理大量的模块和复杂的依赖关系。

3. 高效的代码拆分
Rspack 支持比 Webpack 更细粒度的代码拆分策略，可以智能地拆分代码块，避免不必要的冗余代码加载，提高页面的加载速度。

4. 灵活的配置
与 Webpack 相似，Rspack 提供了灵活的配置选项，但是其配置方式更简洁，降低了学习曲线。你可以通过类似 Webpack 的配置方式进行设置，同时它也支持一些新的功能和优化选项。

说Rspack快，但是，它的最大优势还不是快，而是 Webpack 的无缝替换。你基本上不需要改动配置，直接把配置文件webpack.config.js改名为rspack.config.js即可。
Rspack 不仅兼容 Webpack 的语法，还兼容插件。根据官方文档，下载量最高的50个 Webpack 插件，大部分可以直接使用。
Rspack 团队为了保证兼容性，向 Webpack 官方仓库做了100多次提交。甚至 Webpack 的主要维护者之一的 Alexander Akait 亲自动手，让很多插件可以在 Rspack 正常运行。

# 示例：使用 Rspack 构建一个简单的项目
既然说Rspack快，那到底有多快呢？让我们简单写个例子来验证一下。
这里我们直接采用官方Vue2的示例进行测试[参考示例](https://github.com/rspack-contrib/rspack-examples)。

rspack.config.js
```
const rspack = require('@rspack/core');
const { VueLoaderPlugin } = require('vue-loader');

/** @type {import('@rspack/cli').Configuration} */
const config = {
  context: __dirname,
  entry: {
    main: './src/main.js',
  },
  experiments: {
    css: true,
  },
  devServer: {
    historyApiFallback: true,
  },
  devtool: false,
  plugins: [
    new VueLoaderPlugin(),
    new rspack.HtmlRspackPlugin({
      template: './index.html',
    }),
  ],
  module: {
    rules: [
      {
        test: /\.vue$/,
        use: [
          {
            loader: 'vue-loader',
            options: {
              experimentalInlineMatchResource: true,
            },
          },
        ],
      },
      {
        test: /\.less$/,
        loader: 'less-loader',
        type: 'css',
      },
      {
        test: /\.svg$/,
        type: 'asset/resource',
      },
    ],
  },
};
module.exports = config;
```
webpack.config.js
```
const {VueLoaderPlugin} = require("vue-loader");
const HtmlWebpackPlugin = require('html-webpack-plugin');
const config = {
    context: __dirname,
    entry: {
        main: './src/main.js',
    },
    experiments: {
        css: true,
    },
    devServer: {
        historyApiFallback: true,
    },
    devtool: false,
    plugins: [
        new VueLoaderPlugin(),
        new HtmlWebpackPlugin({ template: './index.html' }),
    ],
    module: {
        rules: [
            {
                test: /\.vue$/,
                use: [
                    {
                        loader: 'vue-loader',
                        options: {
                            experimentalInlineMatchResource: true,
                        },
                    },
                ],
            },
            {
                test: /\.less$/,
                loader: 'less-loader',
                type: 'css',
            },
            {
                test: /\.svg$/,
                type: 'asset/resource',
            },
        ],
    },
};
module.exports = config;
```
在wsl里面，分别执行以下命令进行构建：
```
time npx rspack --config rspack.config.js --mode production
```
最后我们简单对比一下时间：
![时间对比](./images/rspack/result1.png)

# Rspack 的优点：对比 Webpack
1. 构建速度快： Rspack 的最大优势之一是其极速构建能力。与 Webpack 相比，Rspack 在大型项目中的构建速度明显更快，特别是在首次构建和增量构建时，Rspack 能够快速完成任务，极大地提高开发效率。

2. 内存优化： Rspack 在内存使用方面做了大量优化，通过高效的内存管理和模块缓存机制，减少了构建过程中的内存消耗。这使得它在面对大型项目时更加稳定，避免了 Webpack 常见的内存溢出问题。

3. 智能的代码拆分和优化： Rspack 在代码拆分上比 Webpack 更加智能。它可以根据应用的需求，灵活地拆分代码，从而避免了冗余代码的加载，优化了应用的加载速度。

4. 灵活的配置和易用性： 虽然 Rspack 功能强大，但它的配置更加简洁，开发者可以快速上手。相比 Webpack，Rspack 提供了更多开箱即用的优化策略，降低了配置的复杂度。

    >由于全盘继承 Webpack，Rspack 也同时继承了前者的体验问题：配置麻烦，上手不算容易。开发团队为了解决这个问题，在 Rspack 的基础上，封装了一系列更简单易用的衍生工具。

    ![工具栈](./images/rspack/tools.png)

# 结语
Rspack 是一款极具潜力的构建工具，特别适合那些对构建速度和性能有较高要求的前端开发者。它不仅在构建速度上超越了 Webpack，还通过采用 Rust 和其他先进的技术，优化了内存使用和模块处理。对于正在寻找替代 Webpack 的开发者，Rspack 是一个值得尝试的选择。

如果你正在为一个大型项目寻求更高效的构建工具，不妨考虑将 Rspack 作为你的下一代构建工具，享受秒级构建的效率提升，提升开发体验。

这篇博客介绍了 Rspack 的基本特点、配置方法和性能优势，通过实际的代码示例让读者更加直观地了解其使用过程和性能优越性。如果你想根据实际项目的需求进行优化，Rspack 提供了很多灵活的配置选项，帮助你在构建速度和代码质量之间找到最佳平衡点。

