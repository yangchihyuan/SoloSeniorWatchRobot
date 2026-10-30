#!/bin/bash
#Author: Chih-Yuan Yang
#2026 Oct 24
# Exit immediately if a command exits with a non-zero status.
set -e

#The setup.bash loads setup.sh, which sets up the ROS 2 environment variables and paths for the current shell session. This is necessary to run ROS 2 commands and launch files.
#The setup.bash is merely an initial setup script for the bash environment.
source /opt/ros/lyrical/setup.bash
source ~/SoloSeniorWatchRobot/ros2_ws/install/setup.bash # Run this inside your workspace if using local packages

ros2 launch my_robot_bringup robot.launch.py setting_file:=ROGG16_SSWR.json

exit 0 # Indicate successful execution
