from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        # 啟動第一個節點
        Node(
            package='my_first_pkg',   # 你的套件名稱
            executable='my_node',     # setup.py 裡面設定的執行檔名稱
            name='node_A',            # 【覆蓋原本的名稱】改名為 node_A
            output='screen'           # 讓節點的 print/日誌 可以顯示在終端機上
        ),
        
        # 啟動第二個節點
        Node(
            package='my_first_pkg',
            executable='my_node',
            name='node_B',            # 【覆蓋原本的名稱】改名為 node_B
            output='screen'
        )
    ])