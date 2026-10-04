from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        # Start the first node.
        Node(
            package='audio_video_receiver',   # Package name.
            executable='my_node',     # Executable name configured in setup.py.
            name='node_A',            # Override the original name with node_A.
            output='screen'           # Display the node's print output and logs in the terminal.
        ),
        
        # Start the second node.
        Node(
            package='audio_video_receiver',
            executable='my_node',
            name='node_B',            # Override the original name with node_B.
            output='screen'
        )
    ])
