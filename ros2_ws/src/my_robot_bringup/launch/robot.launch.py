#The launch is a ROS 2 package.
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

def generate_launch_description():
    setting_file = LaunchConfiguration('setting_file')

    return LaunchDescription([
        DeclareLaunchArgument(
            'setting_file',
            default_value='ROGG16_SSWR.json',
            description='JSON settings file installed in the server_gui package',
        ),

        # Start the audio/video receiver node.
        Node(
            package='audio_video_receiver',
            executable='android_av_bridge',
            name='android_av_bridge',
            output='screen',
        ),

        # Start the server GUI executable.
        Node(
            package='server_gui',
            executable='SoloSeniorWatchRobot',
            name='server_gui',
            arguments=[
                '--SettingFile',
                PathJoinSubstitution([
                    FindPackageShare('server_gui'),
                    'json',
                    setting_file,
                ]),
            ],
            output='screen',
        ),
    ])
