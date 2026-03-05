#!/bin/zsh

# 脚本: configure-ssh-key.sh
# 功能: 为当前用户配置SSH公钥登录
# 说明: 自动创建必要的目录和文件，确保配置成功

__persiliao_set_strict_mode() {
    # 设置严格模式
    set -euo pipefail
}

__persiliao_show_header() {
    # 显示脚本头信息
    echo "=== SSH公钥配置脚本 ==="
    echo "用户: $(whoami)"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

__persiliao_get_public_key_path() {
    # 获取公钥文件路径
    local pub_key_path="$1"

    if [[ -z "$pub_key_path" ]] || [[ "$pub_key_path" == "--help" ]] || [[ "$pub_key_path" == "-h" ]]; then
        echo "使用方法: $0 [公钥文件路径]"
        echo ""
        echo "示例:"
        echo "  $0 /path/to/login.pub"
        echo "  $0                         # 使用当前目录的 login.pub"
        echo ""
        echo "注意: 此脚本仅为当前用户 $(whoami) 配置SSH公钥登录"
        exit 1
    fi

    if [[ "$pub_key_path" == "." ]] || [[ -z "$pub_key_path" ]]; then
        if [[ -f "login.pub" ]]; then
            pub_key_path="login.pub"
        else
            echo "错误: 未指定公钥文件且当前目录不存在 login.pub"
            exit 1
        fi
    fi

    # 解析路径
    if [[ ! -f "$pub_key_path" ]]; then
        echo "错误: 公钥文件不存在: $pub_key_path"
        exit 1
    fi

    echo "$(realpath "$pub_key_path" 2>/dev/null || echo "$pub_key_path")"
}

__persiliao_validate_public_key() {
    # 验证公钥格式
    local pub_key_path="$1"
    local pub_key_content=""

    echo "验证公钥文件: $pub_key_path"

    # 读取文件内容
    pub_key_content=$(cat "$pub_key_path" 2>/dev/null | tr -d '\r\n' | sed 's/[[:space:]]*$//')

    if [[ -z "$pub_key_content" ]]; then
        echo "错误: 公钥文件内容为空"
        exit 1
    fi

    # 验证基本SSH公钥格式
    if ! echo "$pub_key_content" | grep -q -E "^(ssh-(rsa|dss|ed25519)|ecdsa-sha2-nistp(256|384|521)|ssh-ed25519-cert-v01@openssh\.com)"; then
        echo "错误: 无效的SSH公钥格式"
        echo "支持的格式: ssh-rsa, ssh-dss, ssh-ed25519, ecdsa-sha2-nistp256/384/521"
        echo ""
        echo "文件内容前100字符:"
        echo "$pub_key_content" | cut -c 1-100
        exit 1
    fi

    echo "✓ 公钥格式验证通过"
    echo "  密钥类型: $(echo "$pub_key_content" | awk '{print $1}')"
    echo "  密钥长度: $(echo -n "$pub_key_content" | wc -c | awk '{print $1}') 字符"
    echo ""

    echo "$pub_key_content"
}

__persiliao_create_ssh_directory() {
    # 创建.ssh目录并设置权限
    local ssh_dir="$HOME/.ssh"

    echo "配置SSH目录: $ssh_dir"

    if [[ ! -d "$ssh_dir" ]]; then
        echo "创建.ssh目录..."
        mkdir -p "$ssh_dir"
        echo "✓ 目录已创建"
    else
        echo "✓ 目录已存在"
    fi

    # 确保目录权限正确
    local current_perm=""
    if [[ $(uname) == "Darwin" ]]; then
        current_perm=$(stat -f "%A" "$ssh_dir" 2>/dev/null || echo "755")
    else
        current_perm=$(stat -c "%a" "$ssh_dir" 2>/dev/null || echo "755")
    fi

    if [[ "$current_perm" != "700" ]] && [[ "$current_perm" != "750" ]] && [[ "$current_perm" != "755" ]]; then
        echo "更新目录权限: 0700"
        chmod 700 "$ssh_dir"
    else
        echo "✓ 目录权限正确: $current_perm"
    fi

    echo ""
    echo "$ssh_dir"
}

__persiliao_create_authorized_keys_file() {
    # 创建authorized_keys文件
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    echo "配置authorized_keys文件: $auth_keys_file"

    if [[ ! -f "$auth_keys_file" ]]; then
        echo "创建authorized_keys文件..."
        touch "$auth_keys_file"
        echo "# SSH Authorized Keys for $(whoami)" > "$auth_keys_file"
        echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')" >> "$auth_keys_file"
        echo "" >> "$auth_keys_file"
        echo "✓ 文件已创建"
    else
        echo "✓ 文件已存在"
    fi

    # 确保文件权限正确
    local current_perm=""
    if [[ $(uname) == "Darwin" ]]; then
        current_perm=$(stat -f "%A" "$auth_keys_file" 2>/dev/null || echo "644")
    else
        current_perm=$(stat -c "%a" "$auth_keys_file" 2>/dev/null || echo "644")
    fi

    if [[ "$current_perm" != "600" ]] && [[ "$current_perm" != "644" ]]; then
        echo "更新文件权限: 0600"
        chmod 600 "$auth_keys_file"
    else
        echo "✓ 文件权限正确: $current_perm"
    fi

    echo ""
    echo "$auth_keys_file"
}

__persiliao_backup_existing_keys() {
    # 备份现有的authorized_keys文件
    local auth_keys_file="$1"

    if [[ ! -f "$auth_keys_file" ]]; then
        return 0
    fi

    # 检查文件是否有内容（排除注释和空行）
    local key_count=$(grep -v "^#" "$auth_keys_file" | grep -v "^$" | wc -l | awk '{print $1}')

    if [[ $key_count -eq 0 ]]; then
        echo "ℹ️  文件为空，无需备份"
        return 0
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${auth_keys_file}.backup.${timestamp}"

    echo "备份现有配置..."
    cp "$auth_keys_file" "$backup_file"
    chmod 600 "$backup_file"

    echo "✓ 备份完成: $backup_file"
    echo "  备份包含 $key_count 个有效密钥"
    echo ""

    # 清理旧备份
    __persiliao_cleanup_old_backups "$auth_keys_file"
}

__persiliao_cleanup_old_backups() {
    # 清理旧的备份文件，保留最近5个
    local auth_keys_file="$1"
    local backup_dir=$(dirname "$auth_keys_file")
    local base_name=$(basename "$auth_keys_file")

    local backup_files=($(find "$backup_dir" -name "${base_name}.backup.*" -type f 2>/dev/null | sort -r))
    local backup_count=${#backup_files[@]}

    if [[ $backup_count -gt 5 ]]; then
        echo "清理旧备份文件..."
        for ((i=5; i<backup_count; i++)); do
            echo "  删除: ${backup_files[$i]}"
            rm -f "${backup_files[$i]}"
        done
        echo "✓ 保留最近5个备份"
        echo ""
    fi
}

__persiliao_check_key_exists() {
    # 检查密钥是否已存在
    local auth_keys_file="$1"
    local new_key="$2"

    if [[ ! -f "$auth_keys_file" ]]; then
        return 1
    fi

    echo "检查密钥是否已存在..."

    # 使用多种方法检查
    local temp_file=$(mktemp)
    echo "$new_key" > "$temp_file"

    # 方法1: 使用ssh-keygen检查指纹
    if command -v ssh-keygen >/dev/null 2>&1; then
        local new_fingerprint=$(ssh-keygen -lf "$temp_file" 2>/dev/null | awk 'NR==1{print $2}')

        if [[ -n "$new_fingerprint" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
                    local temp_line_file=$(mktemp)
                    echo "$line" > "$temp_line_file"
                    local line_fingerprint=$(ssh-keygen -lf "$temp_line_file" 2>/dev/null | awk 'NR==1{print $2}')
                    rm -f "$temp_line_file"

                    if [[ "$line_fingerprint" == "$new_fingerprint" ]]; then
                        rm -f "$temp_file"
                        echo "✓ 发现相同指纹的密钥已存在"
                        return 0
                    fi
                fi
            done < "$auth_keys_file"
        fi
    fi

    # 方法2: 直接比较密钥内容
    local clean_new_key=$(echo "$new_key" | tr -d ' ' | tr -d '\n' | tr -d '\r')

    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            local clean_line=$(echo "$line" | tr -d ' ' | tr -d '\n' | tr -d '\r')
            if [[ "$clean_line" == "$clean_new_key" ]]; then
                rm -f "$temp_file"
                echo "✓ 发现完全相同的密钥已存在"
                return 0
            fi
        fi
    done < "$auth_keys_file"

    rm -f "$temp_file"
    echo "✓ 密钥不存在，可以添加"
    return 1
}

__persiliao_add_public_key() {
    # 添加公钥到authorized_keys
    local auth_keys_file="$1"
    local pub_key_content="$2"

    echo "添加公钥到authorized_keys..."

    # 检查是否需要添加注释
    local key_comment=$(echo "$pub_key_content" | awk '{$1=$2=""; print $0}' | xargs)
    if [[ -z "$key_comment" ]]; then
        key_comment="added-by-script-$(date +%Y%m%d)"
    fi

    # 添加密钥
    echo "# $(date '+%Y-%m-%d %H:%M:%S'): $key_comment" >> "$auth_keys_file"
    echo "$pub_key_content" >> "$auth_keys_file"
    echo "" >> "$auth_keys_file"

    echo "✓ 公钥已添加"
    echo "  注释: $key_comment"
    echo ""
}

__persiliao_verify_configuration() {
    # 验证配置
    local auth_keys_file="$1"
    local pub_key_content="$2"

    echo "验证配置..."

    # 检查文件是否存在
    if [[ ! -f "$auth_keys_file" ]]; then
        echo "错误: authorized_keys文件不存在"
        return 1
    fi

    # 检查权限
    local file_perm=""
    if [[ $(uname) == "Darwin" ]]; then
        file_perm=$(stat -f "%A" "$auth_keys_file" 2>/dev/null || echo "")
    else
        file_perm=$(stat -c "%a" "$auth_keys_file" 2>/dev/null || echo "")
    fi

    if [[ "$file_perm" != "600" ]] && [[ "$file_perm" != "644" ]]; then
        echo "警告: 文件权限可能不正确: $file_perm (应为600或644)"
    else
        echo "✓ 文件权限正确: $file_perm"
    fi

    # 检查密钥是否成功添加
    if grep -q -F "$pub_key_content" "$auth_keys_file"; then
        echo "✓ 密钥已成功添加到文件"
    else
        echo "错误: 密钥未找到在文件中"
        return 1
    fi

    # 统计密钥数量
    local key_count=$(grep -v "^#" "$auth_keys_file" | grep -v "^$" | grep -c "ssh-" || echo "0")
    echo "✓ 文件中共有 $key_count 个SSH密钥"
    echo ""

    return 0
}

__persiliao_generate_test_commands() {
    # 生成测试命令
    local current_user=$(whoami)
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    echo "=== 配置完成 ==="
    echo ""
    echo "✅ SSH公钥配置成功！"
    echo ""

    # 显示文件信息
    echo "配置信息:"
    echo "  └─ 用户: $current_user"
    echo "  └─ 配置文件: $auth_keys_file"

    if [[ $(uname) == "Darwin" ]]; then
        echo "  └─ 文件大小: $(stat -f%z "$auth_keys_file" 2>/dev/null || echo "N/A") 字节"
    else
        echo "  └─ 文件大小: $(stat -c%s "$auth_keys_file" 2>/dev/null || echo "N/A") 字节"
    fi

    echo ""
    echo "测试连接:"
    echo ""

    # 生成测试命令
    if command -v hostname >/dev/null 2>&1; then
        local hostname_str=$(hostname)
        echo "1. 本地测试:"
        echo "   ssh ${current_user}@${hostname_str}"
        echo ""
    fi

    echo "2. 通用测试命令:"
    echo "   ssh ${current_user}@localhost"
    echo ""

    # 获取IP地址
    echo "3. 网络连接测试:"
    if [[ $(uname) == "Darwin" ]]; then
        # macOS
        local ip_addresses=$(ifconfig 2>/dev/null | grep -E "inet (192\.168|10\.|172\.)" | awk '{print $2}' | grep -v "127.0.0.1" | head -3)
    else
        # Linux
        local ip_addresses=$(ip -4 addr show 2>/dev/null | grep -E "inet (192\.168|10\.|172\.)" | awk '{print $2}' | cut -d/ -f1 | head -3)
    fi

    if [[ -n "$ip_addresses" ]]; then
        for ip in ${=ip_addresses}; do
            echo "   ssh ${current_user}@${ip}"
        done
    else
        echo "   ssh ${current_user}@<服务器IP地址>"
    fi

    echo ""
    echo "4. 快速测试:"
    echo "   ssh -o ConnectTimeout=5 ${current_user}@localhost 'echo ✅ SSH连接成功'"
    echo ""

    echo "5. 验证命令:"
    echo "   ls -la ~/.ssh/authorized_keys"
    echo "   tail -5 ~/.ssh/authorized_keys"
    echo ""

    echo "注意: 如果连接失败，请确保服务器SSH服务已启用公钥认证"
    echo "      检查: grep 'PubkeyAuthentication yes' /etc/ssh/sshd_config"
    echo ""
    echo "备份文件: ${auth_keys_file}.backup.*"
}

__persiliao_check_ssh_service_status() {
    # 检查SSH服务状态（仅显示信息，不修改）
    echo ""
    echo "SSH服务状态检查:"

    if [[ $(uname) == "Darwin" ]]; then
        # macOS
        local ssh_status=$(sudo launchctl list 2>/dev/null | grep -i ssh || echo "未知")
        echo "  macOS SSH服务: $ssh_status"
    else
        # Linux
        if command -v systemctl >/dev/null 2>&1; then
            systemctl status sshd --no-pager 2>/dev/null | head -3 | grep -E "(active|inactive)" || \
            systemctl status ssh --no-pager 2>/dev/null | head -3 | grep -E "(active|inactive)" || \
            echo "  SSH服务状态: 无法获取"
        elif command -v service >/dev/null 2>&1; then
            service sshd status 2>/dev/null | head -3 || \
            service ssh status 2>/dev/null | head -3 || \
            echo "  SSH服务状态: 无法获取"
        fi
    fi
    echo ""
}

__persiliao_main() {
    # 主函数
    __persiliao_set_strict_mode
    __persiliao_show_header

    local pub_key_path=""
    local pub_key_content=""
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    # 获取公钥文件路径
    if [[ $# -eq 1 ]]; then
        pub_key_path="$1"
    fi

    pub_key_path=$(__persiliao_get_public_key_path "$pub_key_path")

    # 验证公钥
    pub_key_content=$(__persiliao_validate_public_key "$pub_key_path")

    # 创建.ssh目录
    __persiliao_create_ssh_directory > /dev/null

    # 备份现有密钥
    __persiliao_backup_existing_keys "$auth_keys_file"

    # 创建authorized_keys文件
    __persiliao_create_authorized_keys_file > /dev/null

    # 检查密钥是否已存在
    if __persiliao_check_key_exists "$auth_keys_file" "$pub_key_content"; then
        echo "ℹ️  此公钥已存在于配置中，无需重复添加"
        __persiliao_generate_test_commands
        exit 0
    fi

    # 添加公钥
    __persiliao_add_public_key "$auth_keys_file" "$pub_key_content"

    # 验证配置
    if ! __persiliao_verify_configuration "$auth_keys_file" "$pub_key_content"; then
        echo "错误: 配置验证失败"
        exit 1
    fi

    # 生成测试命令
    __persiliao_generate_test_commands

    # 检查SSH服务状态
    __persiliao_check_ssh_service_status

    echo "✅ 配置完成！"
}

# 运行主函数
__persiliao_main "$@"
