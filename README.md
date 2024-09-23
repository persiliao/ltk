# Tools Kit

[![Linux](https://img.shields.io/badge/Linux-ToolKit-blue.svg)](https://www.jetbrains.com/?from=persilia-ltk)
[![](https://img.shields.io/npm/l/el-tree-transfer-pro)](https://github.com/persiliao/ltk/blob/master/LICENSE)
[![使用IDEA开发维护](https://img.shields.io/badge/IDEA-提供支持-blue.svg)](https://www.jetbrains.com/?from=persilia-ltk)

## 初衷

在工作中，经常需要对服务器进行相关的一些配置，于是写了这些常用的一些小工具。

## 特性

#### sh.sh

> 需要使用 `root` 用户执行

* [x] 修改`sshd server` 默认端口
* [x] 设置`sshd keeplive` 保持连接
* [x] 设置`sshd` 禁止root使用密码登录，只允许密钥登录。**注意保存好私钥文件**
* [x] 创建`www`用户组
* [x] 创建普通用户，默认用户名 `deployer` ，推荐主要是用于非`root`操作，例: `docker`, CI/CD远程SSH

#### alias.sh

* [x] 安装一些常用的 `alias` 命令, 安装在 `$HOME/.ltk` 目录下

#### docker.sh

> 需要使用 `root` 用户执行

* [x] 安装 `docker`

#### ohmyzsh.sh

* [x] 安装`zsh`、`ohmyzsh`
* [x] 安装`persi-zsh-theme`(可选)

#### git.sh

* [x] 安装 `git`
* [x] 设置 `git` 常用配置

#### vimrc.sh

* [x] 安装 `vim`
* [x] 安装 `.vimrc` 配置

#### wp.sh

> 需要使用 `root` 用户执行

* [x] 安装 `wp cli`

#### generate_ssl_certificate.sh

> 生成SSL证书

```shell
./generate_ssl_certificate.sh localhost
```

## JetBrains Support

**The project has always been developed in the Idea integrated development environment under JetBrains, based on the
free JetBrains Open Source license(s) genuine free license, I would like to express my gratitude here**

![Jetbrains](https://github.com/persiliao/static-resources/blob/master/jetbrains-logos/jetbrains-variant-4.svg)
