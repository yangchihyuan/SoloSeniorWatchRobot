import rclpy
from rclpy.node import Node

# [Change 1]: Import the custom SensorData message
from my_custom_msgs.msg import SensorData  

class SimplePublisher(Node):
    def __init__(self):
        super().__init__('my_publisher_node')
        # [Change 2]: Change the topic type to SensorData
        self.publisher_ = self.create_publisher(SensorData, 'robot_news', 10)
        self.timer = self.create_timer(1.0, self.timer_callback)
        self.count = 0

    def timer_callback(self):
        # [Change 3]: Create a SensorData object and set its fields
        msg = SensorData()
        msg.sensor_name = f'客廳溫溼度計 (ID:{self.count})'
        msg.temperature = 25 + (self.count % 5)  # Generate sample temperature data that fluctuates
        
        self.publisher_.publish(msg)
        self.get_logger().info(f'發布 -> 感測器: "{msg.sensor_name}", 溫度: {msg.temperature} 度')
        self.count += 1

def main(args=None):
    rclpy.init(args=args)
    node = SimplePublisher()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
