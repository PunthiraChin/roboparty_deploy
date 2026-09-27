# roboparty_deploy

[![许可证：GPL v3](https://img.shields.io/badge/许可证-GPLv3-blue.svg)](LICENSE)

[![ROS2](https://img.shields.io/badge/ROS2-Humble-silver)](https://docs.ros.org/en/humble/index.html)
![C++](https://img.shields.io/badge/C++-17-blue)
[![Linux platform](https://img.shields.io/badge/platform-linux--x86_64-orange.svg)](https://releases.ubuntu.com/22.04/)
[![Linux platform](https://img.shields.io/badge/platform-linux--aarch64-orange.svg)](https://releases.ubuntu.com/22.04/)

[English](README.md) | [中文](README_CN.md)

## 概述

`roboparty_deploy` 是 Roboparty 面向 RPO/Roboto 机器人的 ROS2 部署框架。它采用模块化架构，便于硬件驱动、推理、主控工具和用户脚本独立维护与扩展。

开源地址：[https://github.com/Roboparty/roboparty_deploy](https://github.com/Roboparty/roboparty_deploy)

**维护者**: RoboParty
**支持渠道**: GitHub Issues

**主要特性:**

- **易于上手**: 提供全部细节代码，便于学习并允许修改代码。
- **隔离性**: 不同功能由不同包实现，支持加入自定义功能包。
- **长期支持**: 本仓库将随着训练仓库代码的更新而更新，并将长期支持。

## 主控连接

部署框架在 **Orange Pi 5 Plus** 与 **RDK X5** 上经过了充分验证。

- **Orange Pi 5 Plus**: 系统为 `Ubuntu 22.04`，内核版本为 `5.10`
- **RDK X5**: 系统为 `Ubuntu 22.04`，内核版本为 `6.1.83`

关于主控的连接方法和相关资料，参见 [Orange Pi 5 Plus Wiki](http://www.orangepi.cn/orangepiwiki/index.php/Orange_Pi_5_Plus) 与 [RDK X5 Doc](https://d-robotics.github.io/rdk_doc/Quick_start/hardware_introduction/rdk_x5)。

## 环境配置

1. 首先安装 ROS2 Humble，参考 [ROS 官方](https://docs.ros.org/en/humble/Installation.html) 进行安装。

2. 部署还依赖 `ccache`、`fmt`、`spdlog`、`eigen3`、`screen` 等库，在主控中执行指令进行安装：

   ```bash
   sudo apt update && sudo apt install -y ccache libfmt-dev libspdlog-dev libeigen3-dev screen
   ```

3. 若需使用手柄控制，还需安装 ROS2 的 `joy` 包：

   ```bash
   sudo apt install -y ros-humble-joy
   ```

4. 若需使用仓库中的 Python 脚本（如 `scripts/set_zero.py`），还需安装对应 Python 依赖：

   ```bash
   sudo apt install -y python3-yaml python3-numpy
   ```

5. 接着拉取部署代码：

   ```bash
   git clone --recursive https://github.com/Roboparty/roboparty_deploy.git
   cd roboparty_deploy
   git submodule update --init --recursive
   ```

6. 如果使用 Orange Pi 5 Plus，执行下面的指令为其安装 **5.10 实时内核**：
   
   > **注意**：RDK X5 无需执行此步骤，请直接烧录我们提供的、已预装实时内核的镜像。

   ```bash
   cd assets
   sudo apt install ./*.deb
   cd ..
   ```

7. 接下来为用户授予实时优先级设置权限：

   ```bash
   sudo nano /etc/security/limits.conf
   ```

   在文件末尾添加以下两行（**请务必将 `orangepi` 替换为你的实际用户名**，例如 RDK X5 的默认用户名为 `sunrise`）：

   ```bash
   # Allow user 'orangepi' to set real-time priorities
   orangepi   -   rtprio   98
   orangepi   -   memlock  unlimited
   ```

   重启设备使配置生效，随后通过以下指令验证：

   ```bash
   ulimit -r
   ```

   > **提示**：输出为 **98** 即代表配置成功。

## AP配置（可选）

为方便脱离网线和显示器调试，可以为主控板开启 WiFi 热点（AP）。配置相关文件在 `tools/create_ap` 目录中。

> **注意**：由于单网卡限制，开启 AP 模式后，主控板自带的 WiFi 将难以连接家用路由器等其他外部网络。
>
> - **如需连接外网加载包或环境**，请为主控板**接入有线网络**。
> - **如想暂时恢复无线上网**，可以通过以下命令停止服务（需要外接显示器或网线登录）：
>   ```bash
>   sudo systemctl stop create_ap.service
>   ```

1. 在项目根目录下执行，安装并赋予权限：

   ```bash
   sudo cp tools/create_ap/create_ap /usr/bin/
   sudo chmod +x /usr/bin/create_ap
   ```

2. 部署 systemd 服务文件：

   ```bash
   sudo cp tools/create_ap/create_ap.service /etc/systemd/system/
   ```

3. 根据你的主控板复制配置文件：

   **Orange Pi 5 Plus** 请使用该配置：

   ```bash
   sudo cp tools/create_ap/create_ap_orangepi.conf /etc/create_ap.conf
   ```

   **RDK X5** 请使用该配置：

   ```bash
   sudo cp tools/create_ap/create_ap_sunrise.conf /etc/create_ap.conf
   ```

   > **安全要求**：仓库内配置包含公开的示例凭据，**禁止直接使用该凭据启用热点**。
   > 请为每台机器人生成至少 16 位的唯一密码，并在继续前修改
   > `/etc/create_ap.conf` 中的 `SSID` 和 `PASSPHRASE`：
   >
   > ```bash
   > openssl rand -base64 24
   > sudoedit /etc/create_ap.conf
   > ```
   >
   > 当前 ROS 2 DDS 发现与电机控制服务本身不提供身份认证。请将热点视为隔离的可信
   > 控制网络，并仅向机器人操作人员提供密码。当热点使用公开默认密码或少于 16 位的
   > 密码时，`tools/start_robot.sh` 会拒绝启动。

4. 开启开机自启并立即启动热点：

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable create_ap.service
   sudo systemctl start create_ap.service
   ```

## 硬件配置

在连接之前，请先完成对电机 ID 和 IMU 波特率以及频率的设置。

对于 **电机 ID**，请参见 [产品安装手册](https://roboparty.feishu.cn/wiki/OiO2wF4NiiE08Yk1yJjcgnumnUw) 中对电机 ID 的定义，并使用达妙上位机工具进行设置，使用教程参见 [达妙科技文档](https://gitee.com/kit-miao/damiao-document)。

对于 **IMU**，我们默认使用 **`921600` 波特率** 与 **`500HZ` 频率**。如何使用上位机进行修改参见 [HiPNUC 产品手册](https://www.hipnuc.com/resource_hi14.html)。
> **提示**：也可以使用其他波特率，但请 **保证频率大于 200HZ**。若使用其他波特率，请同步修改 `src/inference/robots/rpo/robot.yaml` 中的 IMU 配置。

## 硬件连接

电机驱动的默认 CAN 映射关系如下（按照 USB 转 CAN 插入主控的顺序编号，先插的为 `can0`）：
- **`can0`** 对应 **左腿**
- **`can1`** 对应 **右腿加腰**
- **`can2`** 对应 **左手**
- **`can3`** 对应 **右手**

> **建议**：将 USB 转 CAN 插在主控的 **USB 3.0 接口**上。如果使用 USB 扩展坞，也请使用 3.0 接口的扩展坞并插在 3.0 接口上；IMU 和手柄插在 USB 2.0 接口即可。具体可参见 [走线说明](https://roboparty.feishu.cn/wiki/QeY2wozbiiIivlkBfdccvqVlnog)。

### 方式一：手动配置（不推荐）
如果不配置 udev 规则，则需要严格按照上文顺序插入 USB 转 CAN，并插入 IMU 后手动配置 CAN 和 IMU 串口：

```bash
# CAN 配置
sudo ip link set canX up type can bitrate 1000000
sudo ip link set canX txqueuelen 1000
# canX 为 can0 can1 can2 can3，需要为每个 can 都输入一遍上面两个指令

# IMU 配置
sudo chmod 666 /dev/ttyUSB0
```

### 方式二：使用 udev 规则自动绑定（推荐）
编写 udev 规则将 USB 接口与对应设备物理绑定，这样就**不需要按顺序插入设备**。示例提供了 `99-auto-up-devs-orangepi.rules` 与 `99-auto-up-devs-sunrise.rules`。如果连线方式与 [走线说明](https://roboparty.feishu.cn/wiki/QeY2wozbiiIivlkBfdccvqVlnog) 完全一致，可直接使用。

接线不一致则需要修改文件中的 `KERNELS` 项，将其对应到实际绑定的 USB 接口。在主控输入以下指令以监视 USB 事件：

```bash
sudo udevadm monitor
```

在 USB 接口插入设备时，终端就会显示该 USB 接口的 `KERNELS` 属性项，如 `/devices/pci0000:00/0000:00:14.0/usb3/3-8`，在匹配 `KERNELS` 属性项时使用 `3-8` 即可。如果绑定在该 USB 接口上的扩展坞上的 USB 口，则会有 `3-8.x` 出现，此时使用 `3-8.x` 匹配扩展坞上的 USB 口即可。

编写完成后在项目根目录下执行：

```bash
# RDK X5 使用 assets/99-auto-up-devs-sunrise.rules
sudo cp assets/99-auto-up-devs-orangepi.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

重启主控即可生效。

该 udev 规则还包括 IMU 串口配置。如果规则正常生效，CAN 接口应该全部自动配置完毕并使能，可以在主控中输入 `ip a` 指令查看结果。

## 软件使用

### 首次构建与终端环境

以下命令均在仓库根目录执行。`/opt/ros/humble/setup.bash` 由 ROS2 Humble 安装提供；本仓库的 `install/setup.bash` 不随源码提供，而是在工作空间首次成功编译后生成。

首次构建，或代码更新后需要重新构建时，按以下顺序执行：

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
```

工作空间已经编译后，每次打开新终端只需重新加载环境：

```bash
source /opt/ros/humble/setup.bash
source install/setup.bash
```

`source` 只对当前终端生效。`start_robot.sh` 和 `start_camera.sh` 会在各自脚本内部执行所需构建并加载工作空间，因此直接运行它们前无需手动生成 `install/setup.bash`；但脚本内部加载的环境不会回传到调用它的终端。脚本返回后，如果还要在当前终端或其他终端调用 ROS2 服务、运行 Python SDK，仍需执行上面的两条 `source` 命令。

### 电机标零（首次使用/零点丢失时）

> **说明**：电机标零通常只需要在首次使用时执行一次；如果电机经过检修、更换，或出现零点丢失，也需要重新执行标零。

仓库内提供了两种零点标定方式，适用于不同场景：

- `ros2 service call /set_zeros std_srvs/srv/Trigger`
  用于在机器人软件已经启动、电机已经初始化且推理未运行时，将当前关节位置写入电机零点。
- `python3 scripts/set_zero.py`
  用于逐个电机进行人工摆位标零，更适合首次装机、检修后重标定或只想对部分电机重新标零的场景。

使用 `/set_zeros` 服务时，建议按以下顺序操作：

1. 在仓库根目录运行 `./tools/start_robot.sh`；脚本会先完成所需构建并生成 `install/setup.bash`，再通过后台 `screen` 会话启动软件并返回当前终端。
2. 脚本启动成功并返回后，在同一终端加载 ROS2 和工作空间环境。
3. 调用 `/init_motors` 初始化电机。
4. 确认机器人处于目标零位，且此时没有运行推理。
5. 调用 `/set_zeros` 写入当前零点。

```bash
# 仓库根目录；以下命令均在同一终端执行
./tools/start_robot.sh
source /opt/ros/humble/setup.bash
source install/setup.bash
ros2 service call /init_motors std_srvs/srv/Trigger
ros2 service call /set_zeros std_srvs/srv/Trigger
```

使用脚本 `scripts/set_zero.py` 时：

1. 在仓库根目录加载 ROS2 环境。
2. 编译工作空间，生成 `install/setup.bash`。
3. 在当前终端加载工作空间环境。
4. 确认 CAN 接口与 udev 映射已正常生效。
5. 按需检查或修改 `scripts/config/set_zero.yaml`，确认电机 ID、CAN 接口、电机型号与实际硬件一致。
6. 在可交互终端中运行脚本后，按提示将当前电机手动摆到零位。
7. 按 `Enter` 写入该电机零点，按空格跳过当前电机。

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
python3 scripts/set_zero.py
```

`scripts/set_zero.py` 会按 `scripts/config/set_zero.yaml` 中的顺序依次标定各电机，并在标定过程中将电机切换到阻尼模式，便于手动调整姿态。

### 启动软件

> **警告**：启动机器人前，确保机器人完成零点标定，**请务必阅读 [安全操作指南](https://roboparty.feishu.cn/wiki/ZGtnwpHCjii2XykBYMGchoBBnSl)！**

此外，请特别注意 `src/inference/robots/rpo/robot.yaml` 中的零点偏移配置：

```yaml
motor_zero_offset: 
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
     0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.093,
     0.0, 0.0, 0.0, 0.0, 0.0,
     0.0, 0.0, 0.0, 0.0, 0.0]
```

- 如果是**将腰部 yaw 转至限位块处**进行标定：保留 `2.093`。
- 如果是**使用打印件固定腰部 yaw** 进行标定：将 `2.093` 改为 `0.0`。

一切准备就绪后，运行脚本启动软件：

```bash
./tools/start_robot.sh
```

默认会启动 `rpo` 机器人的 `default` 策略。也可以显式选择机器人和策略：

```bash
./tools/start_robot.sh --robot rpo --policy amp
./tools/start_robot.sh rpo beyondmimic
```

`./tools/start_robot.sh` 会自动执行 `colcon build --symlink-install` 编译工作空间，并在后台启动以下两个 `screen` 会话：

- `inference_session`：推理节点
- `joy_session`：手柄节点

可使用以下命令查看后台输出：

```bash
screen -r inference_session
screen -r joy_session
```

可使用以下命令停止对应后台组件：

```bash
screen -S inference_session -X quit
screen -S joy_session -X quit
```

如果需要切换不同的策略模型，可以通过 `policy` 参数选择 `src/inference/robots/rpo/configs/` 下的配置：

```bash
./tools/start_robot.sh --robot rpo --policy default
./tools/start_robot.sh --robot rpo --policy amp
./tools/start_robot.sh --robot rpo --policy attn_enc
./tools/start_robot.sh --robot rpo --policy beyondmimic
./tools/start_robot.sh --robot rpo --policy getup
./tools/start_robot.sh --robot rpo --policy interrupt
./tools/start_robot.sh --robot rpo --policy parkour
```

`sawasdee` 配置将默认行走策略与训练好的屈膝 Sawasdee 动作策略组合在一起。
目前该配置标记为 `hardware_validated: false`。物理机器人启动脚本会拒绝它，
推理运行时也会独立阻止电机初始化和推理。请先离线验证策略和动作文件：

```bash
python3 src/inference/tools/validate_motion_policy.py
```

运行契约、硬件批准前所需的验证证据和自动技能选择的安全边界请参阅
`src/inference/robots/rpo/SAWASDEE.md`。

`parkour` 依赖 `/depth_obs` 深度观测。启动机器人推理前，请先在另一个终端启动 RealSense 与深度处理：

```bash
./tools/start_camera.sh --policy parkour
```

#### 稀疏历史观测

`obs_layouts` 中的观测项支持 `name:size@tap|tap` 格式，用于选择该观测项的特定历史帧。`tap` 以推理步为单位：`0` 表示当前帧，`1` 表示上一帧。`tap` 必须是非负整数、不能重复，并且必须小于对应的 `frame_stacks`。未指定 `@` 的观测项仍使用全部历史帧；只要任一观测项指定了 `tap`，该策略就会启用稀疏历史模式。

例如，`parkour` 仅使用当前帧的感知观测，同时保留其他观测项的 8 帧历史：

```yaml
obs_layouts:
  - "ang_vel:3, gravity_b:3, cmd_vel:3, dof_pos:23, dof_vel:23, last_action:23, perception:128@0"
frame_stacks: [8]
obs_stack_orders: ["obs_major"]
```

此配置的输入长度为 `78 × 8 + 128 = 752`。历史观测的排列方式由 `obs_stack_orders` 决定：

- `obs_major`：先按观测项排列，再按 tap 排列；显式指定的 tap 保留书写顺序，未指定 tap 的观测项按最旧帧到当前帧排列。
- `frame_major`：按最旧帧到当前帧排列，每帧内遵循 `obs_layouts` 的顺序；显式 `tap` 必须按严格降序书写，例如 `@4|2|0`。

策略初始化或重置后的首次推理时，当前观测会用于填充全部历史帧。程序启动时会检查最终输入长度是否与 ONNX 模型一致。

### 手柄控制

- **X 键**: 使能 / 失能电机
- **A 键**: 复位电机
- **B 键**: 开始 / 暂停推理
- **Y 键**: 切换手柄控制 / cmd_vel 指令控制
- **LB 键**: 切换策略模式（在 beyondmimic / interrupt 模式下可用）
- **RB 键**: 切换运动序列（在 beyondmimic 模式下可用）
- **右摇杆**: 控制前后左右移动
- **LT/RT**: 控制转向（左 / 右旋转）

### 服务接口

可以通过命令行调用 ROS2 服务来控制机器人：

- **初始化电机**:
  
  ```bash
  ros2 service call /init_motors std_srvs/srv/Trigger
  ```

- **去初始化电机**:

  ```bash
  ros2 service call /deinit_motors std_srvs/srv/Trigger
  ```

- **开始推理**:

  ```bash
  ros2 service call /start_inference std_srvs/srv/Trigger
  ```

- **停止推理**:

  ```bash
  ros2 service call /stop_inference std_srvs/srv/Trigger
  ```

- **清除错误**:

  ```bash
  ros2 service call /clear_errors std_srvs/srv/Trigger
  ```

- **设置零点**:

  ```bash
  ros2 service call /set_zeros std_srvs/srv/Trigger
  ```

  该服务会将机器人当前姿态写入电机零点。调用前请确保当前终端已 source ROS2 和工作空间环境，且电机已初始化、机器人已摆到目标零位、当前没有运行推理。

- **重置关节**:

  ```bash
  ros2 service call /reset_joints std_srvs/srv/Trigger
  ```

- **刷新关节状态**:

  ```bash
  ros2 service call /refresh_joints std_srvs/srv/Trigger
  ```

- **读取关节状态**:

  ```bash
  ros2 service call /read_joints std_srvs/srv/Trigger
  ```

- **读取 IMU 状态**:

  ```bash
  ros2 service call /read_imu std_srvs/srv/Trigger
  ```

## Python SDK

本仓库提供了 Python SDK，方便用户使用 Python 脚本控制硬件。

> **注意**：`imu_py`、`motors_py`、`robot_py` 这三个模块来自工作空间编译产物。运行任何 Python SDK 示例或脚本前，请先完成工作空间编译，并 source ROS2 环境和本工作空间的 `install/setup.bash`。

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
```

> **安全提示**：电机和机器人 SDK 会直接控制真实硬件。运行前请确认机器人已可靠支撑、急停可用，且设备 ID、接口和型号配置正确；不要让多个程序同时控制同一设备。下列相对路径均以仓库根目录为当前目录。

> **提示**：详细 Python 脚本示例请参考 `scripts/` 目录。

### 1. IMU SDK (`imu_py`)

#### 静态方法

- `create_imu(imu_id: int, interface_type: str, interface: str, imu_type: str, baudrate: int = 0) -> IMUDriver`: 创建 IMU 驱动。当前支持 `imu_type="HIPNUC"`，以及 `interface_type="serial"` 或 `"can"`。

`interface` 为串口设备节点（如 `/dev/ttyUSB0`）或 SocketCAN 接口名（如 `can0`）。串口和 CAN 配置都会读取并传递 `baudrate`：串口用它设置通信速率，CAN 则使用已配置为相同波特率的 SocketCAN 接口。`imu_id` 在 CAN 模式下用于匹配设备报文，串口模式下仅作为配置 ID 保存。

#### 成员方法

- `get_imu_id() -> int`: 返回创建实例时传入的 IMU ID，不读取硬件。
- `get_ang_vel() -> List[float]`: 获取最新缓存的角速度 `[x, y, z]` (rad/s)。
- `get_quat() -> List[float]`: 获取最新缓存的四元数 `[w, x, y, z]`。
- `get_lin_acc() -> List[float]`: 获取最新缓存的线加速度 `[x, y, z]` (m/s²)。
- `get_temperature() -> float`: 获取缓存的温度 (°C)；当前串口实现不会更新该字段。

getter 返回 IMU 坐标系中的异步缓存，不会同步读取设备。缓存初始值均为零，且 SDK 不提供时间戳或就绪状态；使用前应等待首个有效数据，并自行处理超时或断线。

#### 使用示例

```python
import time
import imu_py
imu = imu_py.IMUDriver.create_imu(8, "serial", "/dev/ttyUSB0", "HIPNUC", 921600)
time.sleep(0.1)  # 反馈异步更新，先等待首帧
quat = imu.get_quat()
```

### 2. 电机 SDK (`motors_py`)

提供 `MotorControlMode` 枚举：`MIT`、`POS` 和 `SPD` 是工作模式；`NONE` 仅表示尚未设置模式，不应作为控制模式传入。

#### 静态方法

- `create_motor(motor_id: int, interface_type: str, interface: str, motor_type: str, motor_model: int, master_id_offset: int = 0, motor_zero_offset: float = 0.0) -> MotorDriver`: 创建电机驱动并立即打开通信接口。

支持 `DM`、`EVO`、`LRO`、`XYN`；DM/EVO 可使用 CAN 或 CAN-FD，LRO/XYN 使用 CAN-FD。`interface` 为接口名（如 `can0`），`motor_model` 必须与实际型号一致，`master_id_offset` 仅 DM 使用，`motor_zero_offset` 为以 rad 计的软件位置偏移。

#### 成员方法

- `init_motor() -> int`: 初始化并使能电机，返回驱动状态/错误码；该值不是统一的布尔成功标志。
- `deinit_motor()`: 发送失能指令。
- `set_motor_control_mode(mode: MotorControlMode)`: 设置控制模式。
- `motor_mit_cmd(pos: float, vel: float, kp: float, kd: float, torque: float)`: 发送单电机 MIT 指令。位置为 rad，速度为 rad/s，前馈力矩按 N·m 使用，`kp`/`kd` 为驱动协议的刚度/阻尼增益。
- `motors_mit_cmd(f_p: List[float], f_v: List[float], f_kp: List[float], f_kd: List[float], f_t: List[float])`: 发送最多 8 个槽位的批量 MIT 指令；支持情况取决于驱动。
- `motor_pos_cmd(pos: float, spd: float, ignore_limit: bool = False)`: 发送位置指令，单位分别为 rad 和 rad/s。当前所有驱动都忽略 `ignore_limit`；传入 `True` 不会绕过限位。
- `motor_spd_cmd(spd: float)`: 发送速度指令 (rad/s)。
- `set_motor_zero() -> bool`: 将当前电机轴位置设为硬件零点，并返回驱动检查结果。
- `write_motor_flash() -> bool`: 请求保存参数并返回驱动结果。
- `get_motor_param(param_cmd: int)`: 请求驱动参数；当前 Python API 不直接返回参数值。
- `reset_motor_id()`: 按驱动规则重置硬件 ID。
- `clear_motor_error()`: 发送清错指令。
- `get_motor_pos() -> float`: 获取最新缓存的位置 (rad)。
- `get_motor_spd() -> float`: 获取最新缓存的速度 (rad/s)。
- `get_motor_current() -> float`: 获取最新缓存的力矩/电流反馈；物理量取决于驱动。
- `get_motor_temperature() -> float`: 获取最新缓存的温度 (°C)。
- `get_error_id() -> int`: 获取缓存的错误码。
- `get_motor_id() -> int`: 获取本地电机 ID。
- `get_motor_control_mode() -> int`: 获取本地控制模式。
- `get_response_count() -> int`: 获取离线检测计数器；发送请求时递增，收到反馈时清零。
- `refresh_motor_status()`: 执行驱动相关的状态刷新。
- `get_can_name() -> str`: 返回创建时配置的 CAN/CAN-FD 接口名。

首次使用或切换控制模式时，应先调用一次 `set_motor_control_mode()`；否则本次控制调用可能只完成模式切换而不发送目标。反馈 getter 均读取异步缓存，不会主动请求硬件状态。

批量控制、参数持久化、ID 重置和状态刷新的支持情况取决于驱动，使用前请确认对应实现。

#### 使用示例

```python
import motors_py
motor = motors_py.MotorDriver.create_motor(1, "can", "can0", "DM", 0, 16)
try:
    motor.init_motor()
    motor.set_motor_control_mode(motors_py.MotorControlMode.MIT)
    # kp=0，仅施加阻尼，不跟踪位置目标
    motor.motor_mit_cmd(0.0, 0.0, 0.0, 1.0, 0.0)
finally:
    motor.deinit_motor()
```

### 3. 机器人 SDK (`robot_py`)

`RobotInterface` 类用于统一控制整个机器人，读取配置文件自动加载电机和 IMU。

#### 构造函数

- `RobotInterface(config_file: str)`: 读取 YAML 并创建电机和 IMU 驱动。构造时会打开硬件接口，但不会使能电机；相对路径按当前工作目录解析。

所有关节向量均采用配置中的逻辑关节顺序。`p`、`reset_joints()` 的目标以及非空的 `v`、`kp`、`kd`、`tau` 必须与电机数量一致；当前实现不检查长度。

#### 成员方法

- `init_motors() -> None`: 初始化并使能所有电机。
- `deinit_motors() -> None`: 失能所有电机。
- `apply_action(p: List[float], v: List[float] = [], kp: List[float] = [], kd: List[float] = [], tau: List[float] = []) -> None`: 发送关节 MIT 指令；位置为 rad、速度为 rad/s、`tau` 为前馈力矩。空的 `v`/`tau` 使用零值，空的 `kp`/`kd` 使用配置值。电机未初始化时不会发送指令。
- `reset_joints(joint_default_angle: List[float]) -> None`: 用约 5 秒将机器人平滑移动到目标角度。
- `read_joints() -> None`: 将电机异步缓存转换到逻辑关节顺序并更新关节缓存，不主动请求状态。
- `refresh_joints() -> None`: 调用各驱动刷新状态，等待 1 秒后更新关节缓存；具体刷新行为取决于驱动。
- `read_imu() -> None`: 将 IMU 异步缓存转换到机身坐标系并更新 IMU 缓存。
- `set_zeros() -> None`: 将当前电机轴位置设为硬件零点；不会修改配置中的软件偏移或立即刷新关节缓存。
- `clear_errors() -> None`: 向所有电机发送清错指令。
- `get_joint_q() -> List[float]`: 获取缓存的逻辑关节位置 (rad)。
- `get_joint_vel() -> List[float]`: 获取缓存的逻辑关节速度 (rad/s)。
- `get_joint_tau() -> List[float]`: 获取缓存的逻辑关节 effort；其底层物理量和单位取决于电机驱动。
- `get_quat() -> List[float]`: 获取最近一次 `read_imu()` 写入的机身四元数 `[w, x, y, z]`。
- `get_ang_vel() -> List[float]`: 获取最近一次 `read_imu()` 写入的机身角速度 `[x, y, z]` (rad/s)。

getter 只返回 `RobotInterface` 缓存；读取前应先调用对应的 `read_*()` 或 `refresh_joints()`。

#### 属性

- `is_init: bool`: 只读的软件状态，表示已调用初始化且尚未去初始化；不代表所有电机均在线或无故障。

#### 使用示例

```python
import robot_py
robot = robot_py.RobotInterface("src/inference/robots/rpo/robot.yaml")
try:
    robot.init_motors()
    robot.refresh_joints()
    joint_q = robot.get_joint_q()
    robot.apply_action(joint_q)
finally:
    if robot.is_init:
        robot.deinit_motors()
```

## 许可证

除另有说明外，本仓库中由 RoboParty 创作的原创内容依据 [GNU General Public License v3.0 only](LICENSE)（`GPL-3.0-only`）授权。

Git 子模块、已打包二进制文件及其他第三方资料继续遵循其各自的版权和许可证条款；仓库级 GPLv3 声明不会替代这些条款。当前许可证清单和再分发说明见 [LICENSES.md](LICENSES.md)。
