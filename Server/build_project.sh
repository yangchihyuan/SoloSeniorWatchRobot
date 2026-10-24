#!/bin/bash
#Chih-Yuan Yang 2026 Oct 24
#Build the Solo Senior Watch Robot in ROS 2

# Build the ROS 2 workspace
if [ -f /opt/ros/lyrical/setup.bash ]; then
  # The .bashrc entry does not affect this already-running installer shell.
  source /opt/ros/lyrical/setup.bash
else
  echo "Error: ROS 2 Lyrical is not installed at /opt/ros/lyrical."
  exit 1
fi
cd ~/SoloSeniorWatchRobot/ros2_ws
colcon build --symlink-install \
  --packages-select audio_video_receiver server_gui my_robot_bringup
