#!/bin/bash
set -Ee -o pipefail

#Chih-Yuan Yang 2026 Oct 24
#Build the Solo Senior Watch Robot in ROS 2

# The installer calls this script as:
#   ./build_project.sh <RobotModel> <VRAMSize>
# VRAMSize is used to select the CPU or GPU build.  CMake does not need the
# exact VRAM capacity; it only needs USE_GPU to be ON or OFF.
RobotModel="${1:-}"
VRAMSize="${2:-}"

if [[ -z "$RobotModel" || -z "$VRAMSize" ]]; then
  echo "Usage: $0 <Zenbo|ZenboJrII|Kebbi> <VRAMSizeGiB>" >&2
  exit 2
fi

if ! [[ "$VRAMSize" =~ ^[0-9]+$ ]]; then
  echo "Error: VRAMSize must be a non-negative integer (GiB)." >&2
  exit 2
fi

# ZenboJrII uses the Zenbo implementation at build time.  Keep the original
# model name for the installer/runtime configuration, but select the source
# directory that exists in this package.
case "$RobotModel" in
  Zenbo|ZenboJrII)
    CMAKE_ROBOT_MODEL="Zenbo"
    ;;
  Kebbi)
    CMAKE_ROBOT_MODEL="Kebbi"
    ;;
  *)
    echo "Error: unsupported RobotModel '$RobotModel'." >&2
    echo "Usage: $0 <Zenbo|ZenboJrII|Kebbi> <VRAMSizeGiB>" >&2
    exit 2
    ;;
esac

if (( VRAMSize > 0 )); then
  USE_GPU=ON
else
  USE_GPU=OFF
fi

# Build the ROS 2 workspace
if [ -f /opt/ros/lyrical/setup.bash ]; then
  # The .bashrc entry does not affect this already-running installer shell.
  source /opt/ros/lyrical/setup.bash
else
  echo "Error: ROS 2 Lyrical is not installed at /opt/ros/lyrical."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PARENT_DIR"/ros2_ws
colcon build --symlink-install \
  --packages-select audio_video_receiver server_gui my_robot_bringup \
  --cmake-args \
    -DROBOT_MODEL="$CMAKE_ROBOT_MODEL" \
    -DUSE_GPU="$USE_GPU"
