import rclpy
from rclpy.node import Node

# 【修改 1】：改為匯入自訂的 SensorData 訊息
from my_custom_msgs.msg import SensorData

class SimpleSubscriber(Node):
    def __init__(self):
        super().__init__('my_subscriber_node')
        # 【修改 2】：將頻道型態改為 SensorData
        self.subscription = self.create_subscription(
            SensorData,
            'robot_news',
            self.listener_callback,
            10)
        self.subscription

    def listener_callback(self, msg):
        # 【修改 3】：讀取 SensorData 裡面的具體欄位
        self.get_logger().info(
            f'收到資料！ 來自 [{msg.sensor_name}] 的溫度是: {msg.temperature} 度'
        )

def main(args=None):
    rclpy.init(args=args)
    node = SimpleSubscriber()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()