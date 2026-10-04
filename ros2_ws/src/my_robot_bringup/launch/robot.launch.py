from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        # Launch the first package (audio_video_receiver) node
        Node(
            package='audio_video_receiver',         # first package name
            executable='android_av_bridge',   # executable name within the package
            name='android_av_bridge',
            output='screen'
        ),
        # Launch the second package (server_gui) node
        Node(
            package='server_gui',        # second package name
            executable='SoloSeniorWatchRobot',# executable name within the package
            name='server_gui',
            arguments=['json/ROGG16_SSWR.json'],
            output='screen'
        )
    ])
