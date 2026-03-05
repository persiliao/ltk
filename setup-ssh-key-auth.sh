#!/bin/zsh

# 脚本: setup_ssh_key.sh
# 功能: 一键配置SSH使用公钥登录
# 要求: 需要root权限
# 注意: 此脚本同时兼容macOS和Linux

__persiliao_check_root() {
    # 检查是否以root权限运行
    if [[ $EUID -ne 0 ]]; then
        echo "错误: 此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

__persiliao_backup_file() {
    # 备份文件
    local file_path="$1"
    local backup_suffix=".backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$file_path" ]]; then
        cp "$file_path" "${file_path}${backup_suffix}"
        echo "已备份: $file_path -> ${file_path}${backup_suffix}"
    fi
}

__persiliao_setup_ssh_key() {
    local pub_key_path="$1"
    local ssh_dir="/root/.ssh"
    local auth_keys_file="${ssh_dir}/authorized_keys"

    # 验证公钥文件
    if [[ ! -f "$pub_key_path" ]]; then
        echo "错误: 公钥文件不存在: $pub_key_path"
        exit 1
    fi

    # 验证公钥格式
    if ! grep -q "ssh-" "$pub_key_path"; then
        echo "错误: 文件格式不正确，不是有效的SSH公钥: $pub_key_path"
        exit 1
    fi

    echo "正在配置SSH公钥登录..."

    # 创建.ssh目录
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # 备份现有的authorized_keys文件
    __persiliao_backup_file "$auth_keys_file"

    # 添加公钥到authorized_keys
    echo "添加公钥到 ${auth_keys_file}..."

    # 检查公钥是否已存在
    local key_fingerprint=$(ssh-keygen -lf "$pub_key_path" | awk '{print $2}')
    local existing_fingerprints=""

    if [[ -f "$auth_keys_file" ]]; then
        existing_fingerprints=$(ssh-keygen -lf "$auth_keys_file" 2>/dev/null || true)
    fi

    if echo "$existing_fingerprints" | grep -q "$key_fingerprint"; then
        echo "注意: 此公钥已存在于authorized_keys中"
    else
        cat "$pub_key_path" >> "$auth_keys_file"
        echo "✓ 公钥已添加"
    fi

    # 设置正确的权限
    chmod 600 "$auth_keys_file"
    chown -R root:root "$ssh_dir"

    echo "✓ SSH密钥文件权限已设置"
}

__persiliao_configure_sshd() {
    # 配置SSH服务
    local sshd_config="/etc/ssh/sshd_config"
    local sshd_config_dir="/etc/ssh/sshd_config.d"

    echo "配置SSH服务..."

    # 备份sshd_config
    __persiliao_backup_file "$sshd_config"

    # 检查并启用公钥认证
    if grep -q "^#*PubkeyAuthentication" "$sshd_config"; then
        # 修改现有配置
        sed -i'.tmp' -E 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$sshd_config"
    else
        # 添加新配置
        echo "PubkeyAuthentication yes" >> "$sshd_config"
    fi

    # 检查并禁用密码认证（可选，建议）
    if grep -q "^#*PasswordAuthentication" "$sshd_config"; then
        sed -i'.tmp' -E 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$sshd_config"
    else
        echo "PasswordAuthentication no" >> "$sshd_config"
    fi

    # 确保root登录允许
    if grep -q "^#*PermitRootLogin" "$sshd_config"; then
        sed -i'.tmp' -E 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$sshd_config"
    else
        echo "PermitRootLogin prohibit-password" >> "$sshd_config"
    fi

    # 检查是否有额外的配置目录
    if [[ -d "$sshd_config_dir" ]]; then
        echo "注意: 系统使用sshd_config.d目录，请确保其中配置兼容"
    fi

    # 删除临时文件
    rm -f "${sshd_config}.tmp"

    echo "✓ SSH服务配置已更新"
}

__persiliao_restart_sshd() {
    # 重启SSH服务
    echo "重启SSH服务..."

    local os_type=$(uname -s)

    case "$os_type" in
        Linux)
            # 检测Linux发行版
            if [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
                systemctl restart sshd
                systemctl enable sshd
            elif [[ -f /etc/debian_version ]]; then
                systemctl restart ssh
                systemctl enable ssh
            elif [[ -f /etc/alpine-release ]]; then
                rc-service sshd restart
                rc-update add sshd default
            else
                systemctl restart sshd 2>/dev/null || \
                systemctl restart ssh 2>/dev/null || \
                service sshd restart 2>/dev/null || \
                service ssh restart 2>/dev/null
            fi
            ;;
        Darwin)
            # macOS
            launchctl unload /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
            launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
            ;;
        *)
            echo "警告: 未知操作系统类型: $os_type"
            echo "请手动重启SSH服务"
            return 1
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        echo "✓ SSH服务重启完成"
    else
        echo "警告: SSH服务重启可能失败，请手动检查"
    fi
}

__persiliao_test_connection() {
    # 测试连接
    echo ""
    echo "=== 配置完成 ==="
    echo ""
    echo "重要提示: 在关闭当前会话前，请先测试SSH密钥登录是否正常"
    echo ""
    echo "测试命令:"
    echo "1. 在另一个终端中测试连接:"
    echo "   ssh root@$(hostname -I | awk '{print $1}')"
    echo ""
    echo "2. 检查当前配置:"
    echo "   sshd -t  # 测试sshd配置语法"
    echo ""
    echo "3. 查看SSH服务状态:"
    echo "   systemctl status sshd  # 或 systemctl status ssh"
    echo ""
    echo "4. 查看当前会话日志:"
    echo "   tail -f /var/log/auth.log  # 或 /var/log/secure (取决于系统)"
    echo ""
    echo "注意: 如果测试失败，请勿关闭当前会话！"
    echo "      可以恢复备份文件: ${auth_keys_file}.backup.*"
}

__persiliao_cleanup_backups() {
    # 清理旧的备份文件（保留最近3个）
    local backup_dir="/root"
    local file_pattern="authorized_keys.backup.*"

    echo "清理旧的备份文件..."

    # 查找并排序备份文件
    local backup_files=($(find "$backup_dir" -name "$file_pattern" -type f 2>/dev/null | sort))
    local backup_count=${#backup_files[@]}

    if [[ $backup_count -gt 3 ]]; then
        local files_to_delete=$((backup_count - 3))
        for ((j=0; j<files_to_delete; j++)); do
            rm -f "${backup_files[$j]}"
            echo "  删除: ${backup_files[$j]}"
        done
    fi

    echo "✓ 备份文件清理完成"
}

__persiliao_main() {
    # 主函数
    local pub_key_path=""

    # 解析参数
    if [[ $# -eq 1 ]]; then
        pub_key_path="$1"
    elif [[ -f "login.pub" ]]; then
        pub_key_path="login.pub"
    else
        echo "使用方法: $0 [公钥文件路径]"
        echo ""
        echo "如果未指定路径，将尝试使用当前目录的 login.pub"
        echo ""
        echo "示例:"
        echo "  $0 /path/to/login.pub"
        echo "  $0  # 使用当前目录的login.pub"
        exit 1
    fi

    echo "=== SSH公钥一键配置脚本 ==="
    echo "公钥文件: $(realpath "$pub_key_path")"
    echo ""

    # 检查root权限
    __persiliao_check_root

    # 执行配置
    __persiliao_setup_ssh_key "$pub_key_path"
    __persiliao_configure_sshd
    __persiliao_restart_sshd
    __persiliao_cleanup_backups
    __persiliao_test_connection
}

# 运行主函数
__persiliao_main "$@"
