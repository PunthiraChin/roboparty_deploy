# roboparty_deploy

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

[![ROS2](https://img.shields.io/badge/ROS2-Humble-silver)](https://docs.ros.org/en/humble/index.html)
![C++](https://img.shields.io/badge/C++-17-blue)
[![Linux platform](https://img.shields.io/badge/platform-linux--x86_64-orange.svg)](https://releases.ubuntu.com/22.04/)
[![Linux platform](https://img.shields.io/badge/platform-linux--aarch64-orange.svg)](https://releases.ubuntu.com/22.04/)

[English](README.md) | [中文](README_CN.md)

## Overview

`roboparty_deploy` provides the ROS2 deployment framework for Roboparty RPO/Roboto robots. It uses a modular architecture so hardware drivers, inference, controller tools, and user-facing scripts can be maintained and extended independently.

Open-source repository: [https://github.com/Roboparty/roboparty_deploy](https://github.com/Roboparty/roboparty_deploy)

**Maintainer**: RoboParty
**Support**: GitHub Issues

**Key Features:**

- **Easy to Use**: Provides complete detailed code for learning and allows code modification.
- **Isolation**: Different functions are implemented by different packages, supporting the addition of custom function packages.
- **Long-term Support**: This repository will be updated along with the training repository code and will provide long-term support.

## Controller Connection

The deployment framework has been fully verified on **Orange Pi 5 Plus** and **RDK X5**.

- **Orange Pi 5 Plus**: OS is `Ubuntu 22.04`, kernel version is `5.10`
- **RDK X5**: OS is `Ubuntu 22.04`, kernel version is `6.1.83`

For controller connection methods and related resources, see [Orange Pi 5 Plus Wiki](http://www.orangepi.cn/orangepiwiki/index.php/Orange_Pi_5_Plus) and [RDK X5 Doc](https://d-robotics.github.io/rdk_doc/Quick_start/hardware_introduction/rdk_x5).

## Environment Setup

1. First, install ROS2 Humble. Refer to [ROS Official](https://docs.ros.org/en/humble/Installation.html) for installation.

2. The deployment also depends on libraries such as `ccache`, `fmt`, `spdlog`, `eigen3`, and `screen`. Execute the following instruction on the controller to install:

   ```bash
   sudo apt update && sudo apt install -y ccache libfmt-dev libspdlog-dev libeigen3-dev screen
   ```

3. If you want to use gamepad control, also install the ROS2 `joy` package:

   ```bash
   sudo apt install -y ros-humble-joy
   ```

4. If you want to use the Python scripts in this repository (such as `scripts/set_zero.py`), also install the required Python dependencies:

   ```bash
   sudo apt install -y python3-yaml python3-numpy
   ```

5. Next, clone the deployment code:

   ```bash
   git clone --recursive https://github.com/Roboparty/roboparty_deploy.git
   cd roboparty_deploy
   git submodule update --init --recursive
   ```

6. If using Orange Pi 5 Plus, execute the following instructions to install the **5.10 real-time kernel**:
   
   > **Note**: For RDK X5, there is no need to perform this step. Please directly flash the image we provide that has the real-time kernel pre-installed.

   ```bash
   cd assets
   sudo apt install ./*.deb
   cd ..
   ```

7. Next, grant the user permission to set real-time priorities:

   ```bash
   sudo nano /etc/security/limits.conf
   ```

   Add the following two lines at the end of the file (**be sure to replace `orangepi` with your actual username**, for example, the default username for RDK X5 is `sunrise`):

   ```bash
   # Allow user 'orangepi' to set real-time priorities
   orangepi   -   rtprio   98
   orangepi   -   memlock  unlimited
   ```

   Restart the device to make the configuration take effect, and then verify it through the following command:

   ```bash
   ulimit -r
   ```

   > **Tip**: An output of **98** indicates a successful configuration.

## AP Configuration (Optional)

To facilitate debugging without an Ethernet cable and monitor, a WiFi Access Point (AP) can be enabled for the controller board. Configuration-related files are in the `tools/create_ap` directory.

> **Note**: Due to the limitation of a single network card, after enabling the AP mode, the built-in WiFi of the controller board will be difficult to connect to external networks such as a home router.
>
> - **If you need to connect to the external network to download packages or environments**, please **connect a wired network** to the controller board.
> - **If you temporarily want to restore wireless Internet access**, you can stop the service through the following command (requires a monitor or wired connection to log in):
>   ```bash
>   sudo systemctl stop create_ap.service
>   ```

1. Execute in the project root directory to install and grant permissions:

   ```bash
   sudo cp tools/create_ap/create_ap /usr/bin/
   sudo chmod +x /usr/bin/create_ap
   ```

2. Deploy systemd service file:

   ```bash
   sudo cp tools/create_ap/create_ap.service /etc/systemd/system/
   ```

3. Copy the configuration file according to your controller board:

   For **Orange Pi 5 Plus** please use this configuration:

   ```bash
   sudo cp tools/create_ap/create_ap_orangepi.conf /etc/create_ap.conf
   ```

   For **RDK X5** please use this configuration:

   ```bash
   sudo cp tools/create_ap/create_ap_sunrise.conf /etc/create_ap.conf
   ```

   > **Description**: Under the default configuration, the hotspot name (`SSID`) is **`atom`** and the password (`PASSPHRASE`) is **`jujujuju`**. To customize the hotspot name or password, you can edit the `/etc/create_ap.conf` file and modify the corresponding fields.

4. Enable autostart on boot and start the hotspot immediately:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable create_ap.service
   sudo systemctl start create_ap.service
   ```

## Hardware Configuration

Before connecting, please complete the motor ID setup and configure the IMU baud rate and frequency.

For the **motor ID**, please refer to the motor ID definition in [RoboParty Roboto Origin Product Installation Manual](https://roboparty.feishu.cn/wiki/OiO2wF4NiiE08Yk1yJjcgnumnUw), and use the Damiao host computer tool to set it. For tutorials, please see [Damiao Technology Docs](https://gitee.com/kit-miao/damiao-document).

For the **IMU**, we use **`921600` baud rate** and **`500HZ` frequency** by default. How to modify it using the host computer, see the [HiPNUC Product Manual](https://www.hipnuc.com/resource_hi14.html).
> **Tip**: Other baud rates can also be used, but please **ensure the frequency is greater than 200HZ**. If a different baud rate is used, synchronously modify the IMU configuration in `src/inference/robots/rpo/robot.yaml`.

## Hardware Connection

The default CAN mapping relationship for motor drivers is as follows (numbered in the order USB-to-CAN is inserted into the controller, the first inserted is `can0`):
- **`can0`** corresponds to **Left leg**
- **`can1`** corresponds to **Right leg and waist**
- **`can2`** corresponds to **Left hand**
- **`can3`** corresponds to **Right hand**

> **Recommendation**: Plug the USB-to-CAN into the **USB 3.0 interface** of the controller. If using a USB hub, please also use a 3.0 interface hub and plug it into a 3.0 interface; IMU and gamepad can be plugged into USB 2.0 interfaces. For specific details, refer to [RoboParty Roboto Origin Wiring Instructions](https://roboparty.feishu.cn/wiki/QeY2wozbiiIivlkBfdccvqVlnog).

### Method 1: Manual Configuration (Not Recommended)
If you don't configure udev rules, you need to firmly follow the order above to insert USB-to-CAN, and after inserting the IMU, manually configure the CAN and IMU serial ports:

```bash
# CAN Configuration
sudo ip link set canX up type can bitrate 1000000
sudo ip link set canX txqueuelen 1000
# canX is can0, can1, can2, can3, you need to input the above two instructions for each can

# IMU Configuration
sudo chmod 666 /dev/ttyUSB0
```

### Method 2: Use udev rules for automatic binding (Recommended)
Write udev rules to physically bind USB interfaces to corresponding devices, so **you don't need to insert devices in order**. We provide examples `99-auto-up-devs-orangepi.rules` and `99-auto-up-devs-sunrise.rules`. If your wiring is exactly the same as [RoboParty Roboto Origin Wiring Instructions](https://roboparty.feishu.cn/wiki/QeY2wozbiiIivlkBfdccvqVlnog), you can use them directly.

If the wiring is inconsistent, you need to modify the `KERNELS` item in the file to correspond to the actually bound USB interface. Enter the following instruction on the controller to monitor USB events:

```bash
sudo udevadm monitor
```

When a device is inserted into the USB port, the terminal will display the `KERNELS` attribute item of that USB interface, such as `/devices/pci0000:00/0000:00:14.0/usb3/3-8`. Use `3-8` when matching the `KERNELS` attribute. If it's bound to a USB port on a hub connected to that interface, `3-8.x` will appear. In this case, use `3-8.x` to match the USB port on the hub.

After writing, execute in the project root directory:

```bash
# For RDK X5, use assets/99-auto-up-devs-sunrise.rules
sudo cp assets/99-auto-up-devs-orangepi.rules /etc/udev/rules.d/
sudo udevadm control --reload
sudo udevadm trigger
```

Restart the controller for it to take effect.

The udev rules also include the IMU serial port configuration. If the rules take effect normally, all CAN interfaces should automatically finish configuration and be enabled. You can check the results by entering the `ip a` command on the controller.

## Software Usage

### Initial Build and Terminal Environment

Run the following commands from the repository root. `/opt/ros/humble/setup.bash` is provided by the ROS2 Humble installation. This repository's `install/setup.bash` is not included in the source tree; it is generated after the workspace is built successfully for the first time.

For the initial build, or whenever source changes require a rebuild, use this order:

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
```

After the workspace has been built, a new terminal only needs to load the environments again:

```bash
source /opt/ros/humble/setup.bash
source install/setup.bash
```

`source` only affects the current terminal. `start_robot.sh` and `start_camera.sh` perform their required builds and load the workspace inside their own processes, so `install/setup.bash` does not need to exist before running them directly. However, that environment does not propagate back to the terminal that invoked the script. After a script returns, source both environments in any terminal where you want to call ROS2 services or use the Python SDK.

### Motor Zeroing (Initial Setup / Zero Loss)

> **Note**: Motor zeroing usually only needs to be performed once during the initial setup. Run it again only if a motor has been serviced, replaced, or has lost its zero point.

The repository provides two zero-calibration methods for different situations:

- `ros2 service call /set_zeros std_srvs/srv/Trigger`
  Use this when the robot software is already running, the motors have been initialized, and inference is not running. It writes the current joint positions into the motor zero points.
- `python3 scripts/set_zero.py`
  Use this for manual per-motor zeroing. It is better suited for first-time setup, recalibration after maintenance, or recalibrating only part of the robot.

For the `/set_zeros` service, the recommended sequence is:

1. From the repository root, run `./tools/start_robot.sh`. The script performs the required build, generates `install/setup.bash`, starts the software in background `screen` sessions, and then returns to the current terminal.
2. After the script starts successfully and returns, load the ROS2 and workspace environments in the same terminal.
3. Call `/init_motors` to initialize the motors.
4. Move the robot to the target zero pose and make sure inference is not running.
5. Call `/set_zeros` to write the current zero positions.

```bash
# Repository root; run all commands below in the same terminal
./tools/start_robot.sh
source /opt/ros/humble/setup.bash
source install/setup.bash
ros2 service call /init_motors std_srvs/srv/Trigger
ros2 service call /set_zeros std_srvs/srv/Trigger
```

For the `scripts/set_zero.py` script:

1. Load the ROS2 environment from the repository root.
2. Build the workspace to generate `install/setup.bash`.
3. Load the workspace environment in the current terminal.
4. Make sure the CAN interfaces and udev mappings are already working.
5. Check or edit `scripts/config/set_zero.yaml` as needed so the motor IDs, CAN interfaces, and motor models match the hardware.
6. Run the script in an interactive terminal and manually move each motor to its target zero position when prompted.
7. Press `Enter` to write the zero for the current motor, or press Space to skip it.

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
python3 scripts/set_zero.py
```

`scripts/set_zero.py` calibrates motors in the order defined in `scripts/config/set_zero.yaml` and switches each motor into damping mode during calibration so the pose can be adjusted by hand.

### Start Software

> **Warning**: Before starting the robot, ensure the robot has completed zero point calibration. **Please be sure to read [RoboParty Roboto Origin Safety Operation Guide](https://roboparty.feishu.cn/wiki/ZGtnwpHCjii2XykBYMGchoBBnSl) first.**

Additionally, pay special attention to the zero point offset configuration in `src/inference/robots/rpo/robot.yaml`:

```yaml
motor_zero_offset: 
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
     0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.093,
     0.0, 0.0, 0.0, 0.0, 0.0,
     0.0, 0.0, 0.0, 0.0, 0.0]
```

- If you calibrate by **turning the waist yaw to the limit block**: keep `2.093`.
- If you **use a 3D printed part to fix the waist yaw** for calibration: change `2.093` to `0.0`.

Once everything is ready, run the script to start the software:

```bash
./tools/start_robot.sh
```

By default, this starts the `default` policy for the `rpo` robot. You can also select the robot and policy explicitly:

```bash
./tools/start_robot.sh --robot rpo --policy amp
./tools/start_robot.sh rpo beyondmimic
```

`./tools/start_robot.sh` automatically runs `colcon build --symlink-install` to build the workspace and starts the following two `screen` sessions in the background:

- `inference_session`: inference node
- `joy_session`: joystick node

Use the following commands to inspect their output:

```bash
screen -r inference_session
screen -r joy_session
```

Use the following commands to stop the corresponding background components:

```bash
screen -S inference_session -X quit
screen -S joy_session -X quit
```

If you need to switch to a different policy model, pass the `policy` argument. It selects a config from `src/inference/robots/rpo/configs/`:

```bash
./tools/start_robot.sh --robot rpo --policy default
./tools/start_robot.sh --robot rpo --policy amp
./tools/start_robot.sh --robot rpo --policy attn_enc
./tools/start_robot.sh --robot rpo --policy beyondmimic
./tools/start_robot.sh --robot rpo --policy getup
./tools/start_robot.sh --robot rpo --policy interrupt
./tools/start_robot.sh --robot rpo --policy parkour
./tools/start_robot.sh --robot rpo --policy sawasdee
```

The `sawasdee` configuration pairs the stock locomotion controller with the
trained knee-bend Sawasdee policy. Before using robot hardware, validate the
policy and motion bundle offline:

```bash
python3 src/inference/tools/validate_motion_policy.py
```

See `src/inference/robots/rpo/SAWASDEE.md` for the runtime contract, gamepad
flow, and the safety boundary for future autonomous skill selection.

`parkour` depends on the `/depth_obs` observation. Before starting robot inference, launch RealSense and depth processing in another terminal:

```bash
./tools/start_camera.sh --policy parkour
```

#### Sparse Observation History

Entries in `obs_layouts` support the `name:size@tap|tap` format to select specific history frames for an observation source. A tap is measured in inference steps: `0` is the current frame and `1` is the previous frame. Taps must be non-negative, unique, and smaller than the corresponding `frame_stacks` value. Entries without `@` still use all history frames. Specifying taps for any entry enables sparse history mode for that policy.

For example, `parkour` uses only the current perception observation while retaining eight frames for the other observation sources:

```yaml
obs_layouts:
  - "ang_vel:3, gravity_b:3, cmd_vel:3, dof_pos:23, dof_vel:23, last_action:23, perception:128@0"
frame_stacks: [8]
obs_stack_orders: ["obs_major"]
```

The resulting input contains `78 × 8 + 128 = 752` values. `obs_stack_orders` determines how the history is arranged:

- `obs_major`: observations are grouped by source and then by tap. Explicit taps preserve their written order; entries without taps are arranged from the oldest frame to the current frame.
- `frame_major`: frames are arranged from oldest to current, with entries in `obs_layouts` order within each frame. Explicit taps must be strictly descending, for example `@4|2|0`.

On the first inference step after policy initialization or reset, the current observation fills every history slot. At startup, the resulting input size is checked against the ONNX model.

### Gamepad Control

- **X Button**: Initialize / Deinitialize motors
- **A Button**: Reset motors
- **B Button**: Start / Pause inference
- **Y Button**: Switch between Gamepad Control / cmd_vel Control
- **LB Button**: Switch policy mode (available in beyondmimic / interrupt modes)
- **RB Button**: Switch motion sequence (available in beyondmimic mode)
- **Right Stick**: Control forward, backward, left and right movement
- **LT/RT**: Control turning (left / right rotation)

### Service Interface

You can control the robot by calling ROS2 services via command line:

- **Initialize Motors**:
  
  ```bash
  ros2 service call /init_motors std_srvs/srv/Trigger
  ```

- **Deinitialize Motors**:

  ```bash
  ros2 service call /deinit_motors std_srvs/srv/Trigger
  ```

- **Start Inference**:

  ```bash
  ros2 service call /start_inference std_srvs/srv/Trigger
  ```

- **Stop Inference**:

  ```bash
  ros2 service call /stop_inference std_srvs/srv/Trigger
  ```

- **Clear Errors**:

  ```bash
  ros2 service call /clear_errors std_srvs/srv/Trigger
  ```

- **Set Zeros**:

  ```bash
  ros2 service call /set_zeros std_srvs/srv/Trigger
  ```

  This service writes the robot's current pose into the motor zero points. Before calling it, make sure the current terminal has sourced ROS2 and the workspace environment, the motors are initialized, the robot is already in the target zero pose, and inference is not running.

- **Reset Joints**:

  ```bash
  ros2 service call /reset_joints std_srvs/srv/Trigger
  ```

- **Refresh Joint States**:

  ```bash
  ros2 service call /refresh_joints std_srvs/srv/Trigger
  ```

- **Read Joints**:

  ```bash
  ros2 service call /read_joints std_srvs/srv/Trigger
  ```

- **Read IMU**:

  ```bash
  ros2 service call /read_imu std_srvs/srv/Trigger
  ```

## Python SDK

This repository provides a Python SDK to facilitate hardware control using Python scripts.

> **Note**: The `imu_py`, `motors_py`, and `robot_py` modules are generated from the workspace build output. Before running any Python SDK example or script, first build the workspace and source both the ROS2 environment and this workspace's `install/setup.bash`.

```bash
source /opt/ros/humble/setup.bash
colcon build --symlink-install
source install/setup.bash
```

> **Safety**: The motor and robot SDKs directly control real hardware. Before use, securely support the robot, make an emergency stop available, and verify all device IDs, interfaces, and models. Do not let multiple programs control the same device. Relative paths below assume the repository root is the current directory.

> **Tip**: For detailed Python script examples, please refer to the `scripts/` directory.

### 1. IMU SDK (`imu_py`)

#### Static Methods

- `create_imu(imu_id: int, interface_type: str, interface: str, imu_type: str, baudrate: int = 0) -> IMUDriver`: Create an IMU driver. The current implementation supports `imu_type="HIPNUC"` with `interface_type="serial"` or `"can"`.

`interface` is a serial device such as `/dev/ttyUSB0` or a SocketCAN interface such as `can0`. Both serial and CAN configurations read and pass `baudrate`: serial uses it as the communication rate, while CAN uses a SocketCAN interface configured to the same bitrate. In CAN mode, `imu_id` identifies incoming device frames; in serial mode, it is stored only as a configuration ID.

#### Member Methods

- `get_imu_id() -> int`: Return the IMU ID passed at construction; this does not read the hardware.
- `get_ang_vel() -> List[float]`: Get the latest cached angular velocity `[x, y, z]` (rad/s).
- `get_quat() -> List[float]`: Get the latest cached quaternion `[w, x, y, z]`.
- `get_lin_acc() -> List[float]`: Get the latest cached linear acceleration `[x, y, z]` (m/s²).
- `get_temperature() -> float`: Get cached temperature (°C); the current serial implementation does not update this field.

Getters return asynchronous values in the IMU frame and do not synchronously read the device. Caches start at zero, and the SDK provides no timestamp or ready flag; wait for the first valid sample and handle timeouts or disconnection in the application.

#### Example

```python
import time
import imu_py
imu = imu_py.IMUDriver.create_imu(8, "serial", "/dev/ttyUSB0", "HIPNUC", 921600)
time.sleep(0.1)  # Feedback is asynchronous; wait for the first sample
quat = imu.get_quat()
```

### 2. Motor SDK (`motors_py`)

The `MotorControlMode` enum provides `MIT`, `POS`, and `SPD` as operating modes. `NONE` only means that no mode has been set and should not be passed as a control mode.

#### Static Methods

- `create_motor(motor_id: int, interface_type: str, interface: str, motor_type: str, motor_model: int, master_id_offset: int = 0, motor_zero_offset: float = 0.0) -> MotorDriver`: Create a motor driver and immediately open its communication interface.

Supported motor types are `DM`, `EVO`, `LRO`, and `XYN`. DM/EVO use CAN or CAN-FD, while LRO/XYN use CAN-FD. `interface` is an interface name such as `can0`, `motor_model` must match the hardware, only DM uses `master_id_offset`, and `motor_zero_offset` is a software position offset in radians.

#### Member Methods

- `init_motor() -> int`: Initialize and enable the motor, returning a driver status/error code rather than a common Boolean result.
- `deinit_motor()`: Send a disable command.
- `set_motor_control_mode(mode: MotorControlMode)`: Set the control mode.
- `motor_mit_cmd(pos: float, vel: float, kp: float, kd: float, torque: float)`: Send a single-motor MIT command. Position is in radians, velocity in rad/s, feed-forward torque is used as N·m, and `kp`/`kd` are the stiffness/damping gains defined by the driver protocol.
- `motors_mit_cmd(f_p: List[float], f_v: List[float], f_kp: List[float], f_kd: List[float], f_t: List[float])`: Send batched MIT commands for up to eight slots; support depends on the driver.
- `motor_pos_cmd(pos: float, spd: float, ignore_limit: bool = False)`: Send a position command in radians with speed in rad/s. Every current driver ignores `ignore_limit`; passing `True` does not bypass limits.
- `motor_spd_cmd(spd: float)`: Send a speed command (rad/s).
- `set_motor_zero() -> bool`: Set the current motor-shaft position as the hardware zero and return the driver's check result.
- `write_motor_flash() -> bool`: Request parameter persistence and return the driver result.
- `get_motor_param(param_cmd: int)`: Request a driver parameter; the current Python API does not return its value directly.
- `reset_motor_id()`: Reset the hardware ID according to the driver rules.
- `clear_motor_error()`: Send a clear-error command.
- `get_motor_pos() -> float`: Get the latest cached position (rad).
- `get_motor_spd() -> float`: Get the latest cached speed (rad/s).
- `get_motor_current() -> float`: Get the latest cached torque/current feedback; the physical quantity depends on the driver.
- `get_motor_temperature() -> float`: Get the latest cached temperature (°C).
- `get_error_id() -> int`: Get the cached error code.
- `get_motor_id() -> int`: Get the local motor ID.
- `get_motor_control_mode() -> int`: Get the local control mode.
- `get_response_count() -> int`: Get the offline-detection counter; requests increment it and feedback clears it.
- `refresh_motor_status()`: Perform a driver-specific status refresh.
- `get_can_name() -> str`: Return the CAN/CAN-FD interface name configured at construction.

Call `set_motor_control_mode()` once before first using or switching a control mode; otherwise, that control call may only change mode without sending its target. Feedback getters read asynchronous caches and do not actively request hardware status.

Support for batched control, parameter persistence, ID reset, and status refresh depends on the driver; check the corresponding implementation before use.

#### Example

```python
import motors_py
motor = motors_py.MotorDriver.create_motor(1, "can", "can0", "DM", 0, 16)
try:
    motor.init_motor()
    motor.set_motor_control_mode(motors_py.MotorControlMode.MIT)
    # kp=0 applies damping without tracking a position target
    motor.motor_mit_cmd(0.0, 0.0, 0.0, 1.0, 0.0)
finally:
    motor.deinit_motor()
```

### 3. Robot SDK (`robot_py`)

The `RobotInterface` class is used to unify the control of the entire robot, automatically loading motors and IMU by reading the configuration file.

#### Constructor

- `RobotInterface(config_file: str)`: Read the YAML file and create the motor and IMU drivers. Construction opens the hardware interfaces but does not enable the motors. Relative paths are resolved from the current working directory.

All joint vectors use the logical order in the configuration. `p`, the target passed to `reset_joints()`, and every non-empty `v`, `kp`, `kd`, and `tau` vector must match the motor count; the current implementation does not validate lengths.

#### Member Methods

- `init_motors() -> None`: Initialize and enable all motors. Driver return codes are not returned to Python.
- `deinit_motors() -> None`: Disable all motors.
- `apply_action(p: List[float], v: List[float] = [], kp: List[float] = [], kd: List[float] = [], tau: List[float] = []) -> None`: Send joint MIT commands. Position is in radians, velocity in rad/s, and `tau` is feed-forward torque. Empty `v`/`tau` vectors use zero, while empty `kp`/`kd` vectors use configured values. No command is sent before motor initialization.
- `reset_joints(joint_default_angle: List[float]) -> None`: Smoothly move the robot to the target angles in about five seconds.
- `read_joints() -> None`: Convert asynchronous motor caches to logical joint order and update the joint cache without actively requesting status.
- `refresh_joints() -> None`: Ask each driver to refresh status, wait one second, and update the joint cache. Exact refresh behavior depends on the driver.
- `read_imu() -> None`: Transform the asynchronous IMU cache into the body frame and update the IMU cache.
- `set_zeros() -> None`: Set each current motor-shaft position as the hardware zero. This does not change configured software offsets or immediately refresh the joint cache.
- `clear_errors() -> None`: Send a clear-error command to all motors.
- `get_joint_q() -> List[float]`: Get cached logical joint positions (rad).
- `get_joint_vel() -> List[float]`: Get cached logical joint velocities (rad/s).
- `get_joint_tau() -> List[float]`: Get cached logical joint effort. Its underlying physical quantity and unit depend on the motor driver.
- `get_quat() -> List[float]`: Get the body-frame quaternion `[w, x, y, z]` written by the most recent `read_imu()`.
- `get_ang_vel() -> List[float]`: Get the body-frame angular velocity `[x, y, z]` (rad/s) written by the most recent `read_imu()`.

Getters only return the `RobotInterface` cache; call the corresponding `read_*()` method or `refresh_joints()` first.

#### Properties

- `is_init: bool`: Read-only software state indicating initialization without subsequent deinitialization; it does not mean that every motor is online or fault-free.

#### Example

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

## License

Unless otherwise stated, original content authored by RoboParty in this repository is licensed under the [GNU General Public License v3.0 only](LICENSE) (`GPL-3.0-only`).

Git submodules, packaged binaries, and other third-party materials retain their own copyright and license terms. The repository-level GPLv3 declaration does not replace those terms. See [LICENSES.md](LICENSES.md) for the current license inventory and redistribution notes.
