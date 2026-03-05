#!/bin/zsh

# 脚本: add-ssh-key.sh
# 功能: 为当前用户添加SSH公钥到authorized_keys
# 说明: 仅操作用户home目录，不修改系统sshd配置

__persiliao_get_public_key_content() {
    # 获取并验证公钥内容
    local pub_key_path="$1"
    local pub_key_content=""

    if [[ ! -f "$pub_key_path" ]]; then
        echo "错误: 公钥文件不存在: $pub_key_path"
        return 1
    fi

    # 读取公钥，去除换行符和尾部空格
    pub_key_content=$(cat "$pub_key_path" | tr -d '\r\n' | sed 's/[[:space:]]*$//')

    if [[ -z "$pub_key_content" ]]; then
        echo "错误: 公钥文件内容为空: $pub_key_path"
        return 1
    fi

    # 验证公钥格式
    if ! echo "$pub_key_content" | grep -q -E "^(ssh-(rsa|dss|ed25519)|ecdsa-sha2-nistp(256|384|521)|ssh-ed25519-cert-v01@openssh.com)"; then
        echo "错误: 无效的SSH公钥格式: $pub_key_path"
        echo "支持的格式: ssh-rsa, ssh-dss, ssh-ed25519, ecdsa-sha2-nistp*, ed25519-cert"
        return 1
    fi

    echo "$pub_key_content"
    return 0
}

__persiliao_ensure_ssh_directory() {
    # 确保.ssh目录存在且有正确权限
    local ssh_dir="$HOME/.ssh"

    if [[ ! -d "$ssh_dir" ]]; then
        echo "创建.ssh目录: $ssh_dir"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        echo "✓ 已创建.ssh目录"
    else
        # 检查现有目录权限
        local current_perm=$(stat -f "%A" "$ssh_dir" 2>/dev/null || stat -c "%a" "$ssh_dir" 2>/dev/null || echo "755")
        if [[ "$current_perm" != "700" ]] && [[ "$current_perm" != "750" ]]; then
            echo "更新.ssh目录权限: 0700"
            chmod 700 "$ssh_dir"
        fi
    fi

    echo "$ssh_dir"
}

__persiliao_backup_authorized_keys() {
    # 备份现有的authorized_keys文件
    local auth_keys_file="$1"

    if [[ -f "$auth_keys_file" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${auth_keys_file}.backup.${timestamp}"
        cp "$auth_keys_file" "$backup_file"
        echo "备份原有文件: $backup_file"

        # 设置备份文件权限
        chmod 600 "$backup_file"

        # 清理超过3个的旧备份
        __persiliao_clean_old_backups "$auth_keys_file"
    fi

    return 0
}

__persiliao_clean_old_backups() {
    # 清理旧的备份文件，保留最近3个
    local auth_keys_file="$1"
    local backup_dir=$(dirname "$auth_keys_file")
    local base_name=$(basename "$auth_keys_file")

    # 查找并排序备份文件
    local backup_files=($(find "$backup_dir" -name "${base_name}.backup.*" -type f 2>/dev/null | sort))
    local backup_count=${#backup_files[@]}

    if [[ $backup_count -gt 3 ]]; then
        echo "清理旧的备份文件..."
        local files_to_remove=$((backup_count - 3))

        for ((i=0; i<files_to_remove; i++)); do
            echo "  删除: ${backup_files[$i]}"
            rm -f "${backup_files[$i]}"
        done
    fi
}

__persiliao_key_already_exists() {
    # 检查公钥是否已存在
    local auth_keys_file="$1"
    local new_key="$2"

    if [[ ! -f "$auth_keys_file" ]]; then
        return 1  # 文件不存在，密钥也不存在
    fi

    # 计算新密钥的指纹
    local new_key_fingerprint=""
    local temp_key_file=$(mktemp)
    echo "$new_key" > "$temp_key_file"

    if command -v ssh-keygen >/dev/null 2>&1; then
        new_key_fingerprint=$(ssh-keygen -lf "$temp_key_file" 2>/dev/null | awk '{print $2}')
    fi

    rm -f "$temp_key_file"

    # 如果没有ssh-keygen，使用简单比较
    if [[ -z "$new_key_fingerprint" ]]; then
        # 简单字符串比较
        while IFS= read -r line; do
            local clean_line=$(echo "$line" | tr -d '\r\n' | sed 's/[[:space:]]*$//')
            if [[ "$clean_line" == "$new_key" ]]; then
                return 0  # 找到相同密钥
            fi
        done < "$auth_keys_file"
        return 1
    else
        # 使用指纹比较
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
                local temp_line_file=$(mktemp)
                echo "$line" > "$temp_line_file"
                local line_fingerprint=$(ssh-keygen -lf "$temp_line_file" 2>/dev/null | awk '{print $2}')
                rm -f "$temp_line_file"

                if [[ "$line_fingerprint" == "$new_key_fingerprint" ]]; then
                    return 0  # 找到相同密钥
                fi
            fi
        done < "$auth_keys_file"
        return 1
    fi
}

__persiliao_add_key_to_file() {
    # 添加密钥到authorized_keys文件
    local auth_keys_file="$1"
    local pub_key_content="$2"

    # 备份原有文件
    __persiliao_backup_authorized_keys "$auth_keys_file"

    # 添加新密钥
    echo "$pub_key_content" >> "$auth_keys_file"

    # 确保文件权限正确
    chmod 600 "$auth_keys_file"

    echo "✓ 公钥已添加到: $auth_keys_file"
    return 0
}

__persiliao_show_current_user_info() {
    # 显示当前用户信息
    local current_user=$(whoami)
    local user_home="$HOME"

    echo "当前用户: $current_user"
    echo "用户目录: $user_home"
    echo ""
}

__persiliao_generate_usage_instructions() {
    # 生成使用说明
    local current_user=$(whoami)
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    echo ""
    echo "=== 配置完成 ==="
    echo ""
    echo "公钥已添加到: $auth_keys_file"
    echo ""
    echo "使用方法:"
    echo ""

    # 显示本机连接信息
    if command -v hostname >/dev/null 2>&1; then
        local hostname_str=$(hostname)
        echo "1. 在本地连接测试:"
        echo "   ssh ${current_user}@${hostname_str}"
        echo ""
    fi

    # 显示IP地址
    echo "2. 从其他机器连接:"

    # 获取IPv4地址
    if command -v ip >/dev/null 2>&1; then
        # Linux ip命令
        local ipv4_addresses=$(ip -4 addr show 2>/dev/null | grep -E "inet (172\.|192\.168|10\.)" | awk '{print $2}' | cut -d/ -f1)
    elif command -v ifconfig >/dev/null 2>&1; then
        # macOS/Linux ifconfig
        local ipv4_addresses=$(ifconfig 2>/dev/null | grep -E "inet (172\.|192\.168|10\.)" | awk '{print $2}')
    fi

    if [[ -n "$ipv4_addresses" ]]; then
        for ip in ${=ipv4_addresses}; do
            echo "   ssh ${current_user}@${ip}"
        done
    else
        echo "   ssh ${current_user}@<服务器IP地址>"
    fi

    echo ""
    echo "3. 注意事项:"
    echo "   - 此配置只对当前用户 '${current_user}' 有效"
    echo "   - 私钥文件需保存在本地客户端机器的 ~/.ssh/ 目录"
    echo "   - 确保私钥文件权限为 600: chmod 600 ~/.ssh/id_rsa"
    echo ""
    echo "4. 测试连接:"
    echo "   ssh -T ${current_user}@localhost 2>&1 | grep -i 'authenticated'"

    echo ""
    echo "5. 如果连接失败，请检查:"
    echo "   - 服务器是否允许公钥认证: grep 'PubkeyAuthentication' /etc/ssh/sshd_config"
    echo "   - 如果显示 'PubkeyAuthentication no' 或 'no'，需要联系管理员启用"
    echo ""
    echo "备份文件: ${auth_keys_file}.backup.*"
}

__persiliao_verify_key_added() {
    # 验证密钥是否成功添加
    local auth_keys_file="$1"
    local pub_key_content="$2"

    if [[ ! -f "$auth_keys_file" ]]; then
        echo "错误: authorized_keys 文件未创建"
        return 1
    fi

    if grep -q -F "$pub_key_content" "$auth_keys_file"; then
        echo "✓ 验证: 公钥已成功写入文件"
        return 0
    else
        echo "警告: 无法在文件中找到添加的公钥"
        return 1
    fi
}

__persiliao_main() {
    # 主函数
    local pub_key_path=""
    local pub_key_content=""

    # 解析参数
    if [[ $# -eq 1 ]] && [[ "$1" != "--help" ]] && [[ "$1" != "-h" ]]; then
        pub_key_path="$1"
    elif [[ -f "login.pub" ]]; then
        pub_key_path="login.pub"
    else
        echo "使用方法: $0 [公钥文件路径]"
        echo ""
        echo "示例:"
        echo "  $0 /path/to/login.pub"
        echo "  $0                         # 使用当前目录的 login.pub"
        echo ""
        echo "功能: 添加SSH公钥到当前用户的 ~/.ssh/authorized_keys"
        exit 1
    fi

    # 显示用户信息
    __persiliao_show_current_user_info

    # 获取公钥内容
    pub_key_content=$(__persiliao_get_public_key_content "$pub_key_path")
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    echo "✓ 公钥格式验证通过"
    echo ""

    # 确保.ssh目录存在
    local ssh_dir=$(__persiliao_ensure_ssh_directory)
    local auth_keys_file="$ssh_dir/authorized_keys"

    # 检查密钥是否已存在
    if __persiliao_key_already_exists "$auth_keys_file" "$pub_key_content"; then
        echo "ℹ️  此公钥已存在于 authorized_keys 中，无需重复添加"
        echo ""
        echo "文件位置: $auth_keys_file"
        exit 0
    fi

    # 添加密钥到文件
    if ! __persiliao_add_key_to_file "$auth_keys_file" "$pub_key_content"; then
        echo "错误: 添加公钥失败"
        exit 1
    fi

    # 验证添加结果
    __persiliao_verify_key_added "$auth_keys_file" "$pub_key_content"

    # 显示使用说明
    __persiliao_generate_usage_instructions
}

# 运行主函数
__persiliao_main "$@"
