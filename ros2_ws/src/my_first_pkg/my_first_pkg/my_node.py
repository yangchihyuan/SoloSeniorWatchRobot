import rclpy
from rclpy.node import Node

class MyFirstNode(Node):
    def __init__(self):
        # 初始化節點名稱為 'hello_node'
        super().__init__('hello_node')
        self.get_logger().info('你好！我的第一個 ROS2 節點成功啟動了！')
        
        # 建立一個計時器，每 1.0 秒執行一次 timer_callback 函數
        self.timer = self.create_timer(1.0, self.timer_callback)

    def timer_callback(self):
        self.get_logger().info('節點正在背景持續運作中...')

def main(args=None):
    rclpy.init(args=args)
    node = MyFirstNode()
    rclpy.spin(node)     # 讓程式停留在這裡持續運作
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()