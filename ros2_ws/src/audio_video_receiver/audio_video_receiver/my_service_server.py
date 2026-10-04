import rclpy
from rclpy.node import Node
from example_interfaces.srv import AddTwoInts # Import the built-in addition service type

class MinimalService(Node):
    def __init__(self):
        super().__init__('minimal_service')
        # Create a service: (service type, 'service name', request callback)
        self.srv = self.create_service(
            AddTwoInts, 'add_two_ints', self.add_two_ints_callback)
        self.get_logger().info('加法伺服器已啟動，等待請求中...')

    def add_two_ints_callback(self, request, response):
        # This function is called when a request is received
        # The request contains a and b; store the result in response.sum
        response.sum = request.a + request.b
        self.get_logger().info(f'收到請求: 計算 {request.a} + {request.b}')
        
        # Return the response so the system can send it back to the client
        return response

def main(args=None):
    rclpy.init(args=args)
    node = MinimalService()
    rclpy.spin(node) # Keep the server running and waiting here
    rclpy.shutdown()

if __name__ == '__main__':
    main()
