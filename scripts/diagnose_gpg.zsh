#!/bin/bash
# save as diagnose-gpg.sh

echo "=== GPG 配置诊断 ==="
echo ""
echo "1. 检查 GPG 版本:"
gpg --version | head -3
echo ""

echo "2. 检查 Git 配置:"
git config --global --get user.signingkey && echo "签名密钥已设置" || echo "签名密钥未设置"
git config --global --get commit.gpgsign && echo "自动签名已启用" || echo "自动签名已禁用"
echo ""

echo "3. 检查 GPG 密钥:"
gpg --list-secret-keys --keyid-format LONG
echo ""

echo "4. 检查 GPG 代理状态:"
gpg-connect-agent "getinfo pid" /bye
echo ""

echo "5. 检查环境变量:"
echo "GPG_TTY: ${GPG_TTY:-未设置}"
echo "TTY: $(tty)"
echo ""

echo "6. 测试签名:"
echo "test" | gpg --clearsign 2>&1 | head -10