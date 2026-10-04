import rclpy
from rclpy.node import Node

class MyFirstNode(Node):
    def __init__(self):
        # Initialize the node with the name 'hello_node'.
        super().__init__('hello_node')
        self.get_logger().info('Hello! My first ROS 2 node has started successfully!')
        
        # Create a timer that calls timer_callback every 1.0 seconds.
        self.timer = self.create_timer(1.0, self.timer_callback)

    def timer_callback(self):
        self.get_logger().info('The node is running in the background...')

def main(args=None):
    rclpy.init(args=args)
    node = MyFirstNode()
    rclpy.spin(node)     # Keep the program running here.
    node.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
