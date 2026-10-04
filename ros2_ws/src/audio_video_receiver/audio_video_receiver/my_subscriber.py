import rclpy
from rclpy.node import Node

# [Change 1]: Import the custom SensorData message
from my_custom_msgs.msg import SensorData

class SimpleSubscriber(Node):
    def __init__(self):
        super().__init__('my_subscriber_node')
        # [Change 2]: Change the topic type to SensorData
        self.subscription = self.create_subscription(
            SensorData,
            'robot_news',
            self.listener_callback,
            10)
        self.subscription

    def listener_callback(self, msg):
        # [Change 3]: Read the specific fields in SensorData
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
