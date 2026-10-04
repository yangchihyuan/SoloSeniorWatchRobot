import sys
import rclpy
from rclpy.node import Node
from example_interfaces.srv import AddTwoInts

class MinimalClient(Node):
    def __init__(self):
        super().__init__('minimal_client')
        # Create a client; the service name must exactly match the server's ('add_two_ints')
        self.cli = self.create_client(AddTwoInts, 'add_two_ints')
        
        # Check whether the server is available; if not, check again every second
        while not self.cli.wait_for_service(timeout_sec=1.0):
            self.get_logger().info('伺服器還沒準備好，等待中...')
            
        self.req = AddTwoInts.Request()

    def send_request(self, a, b):
        self.req.a = a
        self.req.b = b
        # call_async sends the request and returns a Future object
        return self.cli.call_async(self.req)

def main(args=None):
    rclpy.init(args=args)
    client = MinimalClient()
    
    # Let users enter numbers in the terminal; default to 3 + 4 if no input is given
    a = int(sys.argv[1]) if len(sys.argv) == 3 else 3
    b = int(sys.argv[2]) if len(sys.argv) == 3 else 4
    
    # Call the function to send the request
    future = client.send_request(a, b)
    
    # The program blocks here until the server returns the result
    rclpy.spin_until_future_complete(client, future)
    
    # Get and print the result
    response = future.result()
    client.get_logger().info(f'伺服器回傳結果: {a} + {b} = {response.sum}')

    client.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()
