# Tools Kit

## 初衷

在工作中，经常需要对服务器进行相关的一些配置，于是写了这些常用的一些小工具。

## 特性

#### initialize.sh

> 需要使用root用户执行

* [x] 修改sshd server 默认端口
* [x] 设置sshd keeplive 保持连接
* [x] 设置sshd 禁止root使用密码登录，只允许密钥登录。**注意保存好私钥文件**
* [x] 创建www用户组
* [x] 创建普通用户，主要是用于非root操作，例: docker, CI/CD远程SSH

#### alias.sh

* [x] 安装一些常用的alias命令

#### docker.sh

> 需要使用root用户执行

* [x] 安装docker

#### ohmyzsh.sh

* [x] 安装zsh、ohmyzsh
* [x] 安装persi-zsh-theme(可选)

#### git.sh

* [x] 安装git
* [x] 设置 git 常用配置

#### vimrc.sh

* [x] 安装vim
* [x] 安装.vimrc配置

#### wp.sh

* [x] 安装 wp cli
