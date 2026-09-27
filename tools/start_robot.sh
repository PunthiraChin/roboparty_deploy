#!/bin/bash

# 颜色定义，用于美化输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 函数：打印成功消息
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# 函数：打印提示消息
print_info() {
    echo -e "${YELLOW}$1${NC}"
}

# 函数：打印错误消息
print_error() {
    echo -e "${RED}$1${NC}"
}

show_usage() {
    echo "用法: $0 [--robot ROBOT] [--policy POLICY]"
    echo "      $0 [ROBOT] [POLICY]"
    echo
    echo "默认: robot=rpo, policy=default"
    echo "示例: $0 --robot rpo --policy amp"
    echo "示例: $0 rpo beyondmimic"
}

validate_name() {
    local label=$1
    local value=$2

    if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
        print_error "$label 必须以字母或数字开头，且只能包含字母、数字、下划线、短横线和点: $value"
        exit 1
    fi
}

# Parse the literal shell-style assignment without sourcing the configuration.
# Sourcing would let a writable config execute commands as root. shlex matches
# quotes and inline comments while deliberately rejecting substitutions.
read_ap_passphrase() {
    python3 - "$1" <<'PY'
import re
import shlex
import sys
from pathlib import Path

assignments = []
for raw_line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if line.startswith("export "):
        line = line[7:].lstrip()
    match = re.fullmatch(r"PASSPHRASE\s*=\s*(.*)", line)
    if match is None:
        continue
    rhs = match.group(1)
    if "$" in rhs or "`" in rhs:
        raise SystemExit(2)
    lexer = shlex.shlex(rhs, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = "#"
    tokens = list(lexer)
    if len(tokens) != 1:
        raise SystemExit(2)
    assignments.append(tokens[0])

if not assignments:
    raise SystemExit(3)
sys.stdout.write(assignments[-1])
PY
}

# systemctl serializes ExecStart as metadata plus the command argv. Require the
# pinned service's exact, single "--config /etc/create_ap.conf" argument. A
# substring check would incorrectly accept paths such as create_ap.conf.evil.
service_uses_canonical_ap_config() {
    python3 - "$1" <<'PY'
import re
import sys

exec_start = sys.argv[1]
config_flags = re.findall(r"(?<!\S)--config(?=\s|=)", exec_start)
canonical_args = re.findall(
    r"(?<!\S)--config\s+/etc/create_ap\.conf(?=\s|[;}]|$)",
    exec_start,
)
raise SystemExit(0 if len(config_flags) == 1 and len(canonical_args) == 1 else 1)
PY
}

process_belongs_to_cgroup() {
    local cgroup_file=$1
    local expected_cgroup=$2

    [ -r "$cgroup_file" ] && awk -F: -v expected="$expected_cgroup" '
        $3 == expected || index($3, expected "/") == 1 { found=1 }
        END { exit !found }
    ' "$cgroup_file"
}

# The ROS 2 graph exposes motor-control services to every participant on the
# DDS network. Validate the canonical AP config before every robot start, even
# while its managed service is stopped, so it cannot be enabled insecurely
# after the robot is running. If an AP is detected without that config, fail
# closed. This check never prints the passphrase.
validate_ap_security() {
    local ap_config="/etc/create_ap.conf"
    local managed_ap_active=0
    local ap_runtime_detected=0
    local detection_available=0
    local service_cgroup=""
    local ap_process_pids=""
    local ap_interface_count=0

    if command -v systemctl >/dev/null 2>&1; then
        detection_available=1
        if systemctl is-active --quiet create_ap.service; then
            local service_command
            if ! service_command=$(systemctl show --property=ExecStart --value create_ap.service) || \
               ! service_uses_canonical_ap_config "$service_command"; then
                print_error "运行中的 create_ap.service 未绑定固定配置: $ap_config"
                print_error "拒绝启动机器人运行时。"
                exit 1
            fi
            if ! service_cgroup=$(systemctl show --property=ControlGroup --value create_ap.service) || \
               [[ "$service_cgroup" != /* ]]; then
                print_error "无法确认 create_ap.service 的进程边界；拒绝启动机器人运行时。"
                exit 1
            fi
            managed_ap_active=1
        fi
    fi
    if command -v pgrep >/dev/null 2>&1; then
        detection_available=1
        ap_process_pids=$(
            {
                pgrep -x hostapd 2>/dev/null || true
                pgrep -f '(^|/)create_ap([[:space:]]|$)' 2>/dev/null || true
            } | awk '!seen[$1]++'
        )
        if [ -n "$ap_process_pids" ]; then
            ap_runtime_detected=1
        fi
    fi
    if command -v iw >/dev/null 2>&1; then
        detection_available=1
        ap_interface_count=$(iw dev 2>/dev/null | awk '
            $1 == "type" && $2 == "AP" { count++ }
            END { print count + 0 }
        ')
        if [ "$ap_interface_count" -gt 0 ]; then
            ap_runtime_detected=1
        fi
    fi

    if [ "$ap_runtime_detected" -eq 1 ] && [ "$managed_ap_active" -ne 1 ]; then
        print_error "检测到未由 create_ap.service 管理的热点；无法证明其使用固定安全配置。"
        print_error "拒绝启动机器人运行时。"
        exit 1
    fi

    if [ "$managed_ap_active" -eq 1 ]; then
        local ap_pid
        for ap_pid in $ap_process_pids; do
            if ! process_belongs_to_cgroup "/proc/$ap_pid/cgroup" "$service_cgroup"; then
                print_error "检测到 create_ap.service 之外的热点进程 (PID $ap_pid)。"
                print_error "拒绝启动机器人运行时。"
                exit 1
            fi
        done
        if [ "$ap_interface_count" -gt 1 ]; then
            print_error "检测到多个热点接口；无法证明它们全部由固定服务管理。"
            print_error "拒绝启动机器人运行时。"
            exit 1
        fi
    fi

    if [ ! -e "$ap_config" ]; then
        if [ "$managed_ap_active" -eq 1 ] || [ "$detection_available" -eq 0 ]; then
            print_error "检测到热点或无法确认网络状态，但缺少热点配置: $ap_config"
            print_error "拒绝启动机器人运行时。"
            exit 1
        fi
        return 0
    fi
    if [ ! -r "$ap_config" ]; then
        print_error "无法读取热点配置: $ap_config"
        print_error "请先设置每台机器人唯一的强密码，再启动机器人运行时。"
        exit 1
    fi

    local passphrase
    if ! passphrase=$(read_ap_passphrase "$ap_config"); then
        print_error "无法安全解析热点密码配置；拒绝启动机器人运行时。"
        exit 1
    fi

    if [ -z "$passphrase" ] || [ "$passphrase" = "jujujuju" ] || [ "${#passphrase}" -lt 16 ]; then
        print_error "检测到公开默认或过短的热点密码；拒绝启动机器人运行时。"
        print_error "请编辑 $ap_config，设置每台机器人唯一且至少 16 位的密码。"
        exit 1
    fi

    print_success "热点配置安全检查通过（未显示密码）。"
}

# This launcher is the normal physical-robot path, so it only accepts complete
# profiles that explicitly record supervised hardware validation. Offline and
# simulation-only profiles must use their dedicated validation/demo commands.
validate_policy_hardware_gate() {
    local policy_config="$1"
    local validation_value
    validation_value=$(awk '$1 == "hardware_validated:" { print tolower($2); exit }' "$policy_config")
    if [ "$validation_value" != "true" ]; then
        print_error "策略未通过物理硬件验证；拒绝启动机器人运行时: $policy_config"
        print_error "请先完成离线、仿真和有人监督的硬件验证。"
        exit 1
    fi
}

ROBOT="rpo"
POLICY="default"
ROBOT_SET=0
POLICY_SET=0

while [ $# -gt 0 ]; do
    case "$1" in
        --robot|-r)
            if [ $# -lt 2 ]; then
                print_error "缺少 --robot 参数值"
                show_usage
                exit 1
            fi
            ROBOT="$2"
            ROBOT_SET=1
            shift 2
            ;;
        --policy|-p)
            if [ $# -lt 2 ]; then
                print_error "缺少 --policy 参数值"
                show_usage
                exit 1
            fi
            POLICY="$2"
            POLICY_SET=1
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            if [ "$ROBOT_SET" -eq 0 ]; then
                ROBOT="$1"
                ROBOT_SET=1
            elif [ "$POLICY_SET" -eq 0 ]; then
                POLICY="$1"
                POLICY_SET=1
            else
                print_error "未知参数: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

validate_name "robot" "$ROBOT"
validate_name "policy" "$POLICY"

# 函数：启动组件并检查（先启动ROS节点，再设置实时优先级）
start_component() {
    local session_name=$1
    local launch_cmd=$2
    local node_name=$3
    local sleep_time=$4

    print_info "启动 $session_name ..."
    # 在screen会话中启动ROS命令，并确保传递DDS配置环境变量
    screen -dmS $session_name bash -c "source install/setup.bash; export RMW_IMPLEMENTATION='$RMW_IMPLEMENTATION'; export RMW_FASTRTPS_USE_QOS_FROM_XML='$RMW_FASTRTPS_USE_QOS_FROM_XML'; export FASTRTPS_DEFAULT_PROFILES_FILE='$FASTRTPS_DEFAULT_PROFILES_FILE'; $launch_cmd; exec bash"
    sleep $sleep_time

    if ! ros2 node list | grep -q "$node_name"; then
        print_error "$session_name 启动失败！未检测到 $node_name 节点。"
        cleanup_sessions
        exit 1
    fi
}

# 函数：清理所有会话
cleanup_sessions() {
    screen -S inference_session -X quit 2>/dev/null
    screen -S joy_session -X quit 2>/dev/null
}

# 函数：详细验证 DDS 配置是否生效
verify_dds_effectiveness() {
    print_info "详细验证 DDS 配置是否生效..."
    sleep 2
    
    # 1. 检查环境变量
    print_info "检查环境变量..."
    echo "RMW_IMPLEMENTATION: $RMW_IMPLEMENTATION"
    echo "FASTRTPS_DEFAULT_PROFILES_FILE: $FASTRTPS_DEFAULT_PROFILES_FILE"
    
    # 2. 验证配置文件是否被读取
    print_info "验证配置文件读取..."
    if [ -f "$FASTRTPS_DEFAULT_PROFILES_FILE" ]; then
        print_success "配置文件存在"
        
        # 检查XML语法
        if command -v xmllint &> /dev/null; then
            if xmllint --noout "$FASTRTPS_DEFAULT_PROFILES_FILE" 2>/dev/null; then
                print_success "XML 格式正确"
            else
                print_error "XML 格式错误"
                xmllint "$FASTRTPS_DEFAULT_PROFILES_FILE"
                return 1
            fi
        fi
    else
        print_error "配置文件不存在: $FASTRTPS_DEFAULT_PROFILES_FILE"
        return 1
    fi
    
    # 3. 检查进程是否使用了 Fast DDS
    print_info "检查进程 DDS 实现..."
    for node in "inference_node" "joy_node"; do
        local pid=$(pgrep -x "$node" 2>/dev/null)
        if [ -n "$pid" ]; then
            # 检查进程环境变量
            local env_file="/proc/$pid/environ"
            if [ -f "$env_file" ]; then
                if grep -z "FASTRTPS_DEFAULT_PROFILES_FILE" "$env_file" >/dev/null 2>&1; then
                    print_success "$node 环境变量设置正确"
                else
                    print_error "$node 缺少 FASTRTPS_DEFAULT_PROFILES_FILE 环境变量"
                fi
                
                if grep -z "RMW_IMPLEMENTATION=rmw_fastrtps_cpp" "$env_file" >/dev/null 2>&1; then
                    print_success "$node RMW 实现正确"
                else
                    print_error "$node RMW 实现不正确"
                fi
            fi
        fi
    done
    
    # 4. 检查共享内存传输
    print_info "检查共享内存传输..."
    local shm_files=$(ls /dev/shm/ 2>/dev/null | grep -E "(fastrtps|fast_dds|rmw)" | wc -l)
    if [ "$shm_files" -gt 0 ]; then
        print_success "共享内存传输活跃 ($shm_files 个文件)"
    else
        print_error "共享内存传输未检测到"
    fi
    
    # 5. 测试 DDS 发现性能
    print_info "测试 DDS 发现性能..."
    local start_time=$(date +%s%3N)
    ros2 node list >/dev/null 2>&1
    local end_time=$(date +%s%3N)
    local discovery_time=$((end_time - start_time))
    
    if [ "$discovery_time" -lt 500 ]; then
        print_success "DDS 发现延迟: ${discovery_time}ms (优秀)"
    elif [ "$discovery_time" -lt 1000 ]; then
        print_info "DDS 发现延迟: ${discovery_time}ms (良好)"
    else
        print_error "DDS 发现延迟: ${discovery_time}ms (较慢)"
    fi
}

# 切换到脚本目录
cd "$(dirname "$0")"
cd ..

POLICY_FILE="$POLICY"
if [[ "$POLICY_FILE" != *.yaml ]]; then
    POLICY_FILE="${POLICY_FILE}.yaml"
fi

ROBOT_DIR="src/inference/robots/$ROBOT"
if [ ! -f "$ROBOT_DIR/robot.yaml" ]; then
    print_error "机器人配置不存在: $ROBOT_DIR/robot.yaml"
    exit 1
fi
if [ ! -f "$ROBOT_DIR/configs/$POLICY_FILE" ]; then
    print_error "推理配置不存在: $ROBOT_DIR/configs/$POLICY_FILE"
    exit 1
fi

validate_policy_hardware_gate "$ROBOT_DIR/configs/$POLICY_FILE"
validate_ap_security

print_info "选择机器人: $ROBOT"
print_info "选择策略: $POLICY"

# 设置 DDS 配置文件
export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
export RMW_FASTRTPS_USE_QOS_FROM_XML=1
export FASTRTPS_DEFAULT_PROFILES_FILE="$(pwd)/assets/rt_fastdds_profile.xml"
print_info "设置 DDS 配置文件: $FASTRTPS_DEFAULT_PROFILES_FILE"

# 检查 DDS 配置文件是否存在
if [ ! -f "$FASTRTPS_DEFAULT_PROFILES_FILE" ]; then
    print_error "DDS 配置文件不存在: $FASTRTPS_DEFAULT_PROFILES_FILE"
    exit 1
fi

# 检查是否已source setup文件
if [ -z "$AMENT_PREFIX_PATH" ]; then
    print_info "未检测到ROS 2环境，正在执行source..."
    source /opt/ros/humble/setup.bash || {
        print_error "无法source /opt/ros/humble/setup.bash，请检查路径是否正确"
        exit 1
    }
fi

# 检查 colcon 和 ros2
if ! command -v colcon &> /dev/null; then
    print_error "colcon 未安装，请安装 ROS 2 开发工具"
    exit 1
fi
if ! command -v ros2 &> /dev/null; then
    print_error "ros2 未安装"
    exit 1
fi

# 检查是否已安装screen
if ! command -v screen &> /dev/null; then
    print_error "screen 未安装"
    exit 1
fi

# 编译推理包
print_info "编译推理包..."
colcon build --symlink-install || {
    print_error "推理包编译失败"
    exit 1
}
source install/setup.bash

# 停止可能正在运行的screen会话
print_info "停止现有相关screen会话..."
cleanup_sessions

start_component "inference_session" "ros2 launch roboparty_inference inference.launch.py robot:=$ROBOT policy:=$POLICY" "inference_node" 5
start_component "joy_session" "ros2 run joy joy_node" "joy_node" 2

# 验证节点的 DDS 配置
verify_dds_effectiveness

# 所有组件启动完成
print_success "----------------------------------------"
print_success "所有组件已在后台成功启动！"
print_success "使用以下命令查看各组件输出："
print_success "推理模块: screen -r inference_session"
print_success "手柄控制: screen -r joy_session"
print_success "----------------------------------------"
print_info "若要退出某个screen会话，按Ctrl+A然后按D"
print_info "使用以下命令停止所有组件："
print_info "screen -S inference_session -X quit"
print_info "screen -S joy_session -X quit"
print_success "----------------------------------------"
print_info "手柄控制说明:"
print_info "X键: 使能/失能电机"
print_info "A键: 复位电机"
print_info "B键: 开始/暂停推理"
print_info "Y键: 切换手柄控制/cmd_vel指令控制"
print_info "LB键: 切换策略模式(在beyondmimic/interrupt模式下可用)"
print_info "RB键: 切换运动序列(在beyondmimic模式下可用)"
print_info "右摇杆: 控制前后左右移动"
print_info "LT/RT: 控制转向(左/右旋转)"
