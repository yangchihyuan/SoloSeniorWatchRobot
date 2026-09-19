import rclpy
from rclpy.node import Node

# 【修改 1】：改為匯入自訂的 SensorData 訊息
from my_custom_msgs.msg import SensorData  

class SimplePublisher(Node):
    def __init__(self):
        super().__init__('my_publisher_node')
        # 【修改 2】：將頻道型態改為 SensorData
        self.publisher_ = self.create_publisher(SensorData, 'robot_news', 10)
        self.timer = self.create_timer(1.0, self.timer_callback)
        self.count = 0

    def timer_callback(self):
        # 【修改 3】：建立 SensorData 物件並設定欄位
        msg = SensorData()
        msg.sensor_name = f'客廳溫溼度計 (ID:{self.count})'
        msg.temperature = 25 + (self.count % 5)  # 隨便做個會跳動的溫度假資料
        
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