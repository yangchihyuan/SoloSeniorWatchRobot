import sys
import rclpy
from rclpy.node import Node
from example_interfaces.srv import AddTwoInts

class MinimalClient(Node):
    def __init__(self):
        super().__init__('minimal_client')
        # 建立客戶端，服務名稱必須跟伺服端完全一樣 ('add_two_ints')
        self.cli = self.create_client(AddTwoInts, 'add_two_ints')
        
        # 檢查伺服器是否已經上線，如果沒有就每秒檢查一次
        while not self.cli.wait_for_service(timeout_sec=1.0):
            self.get_logger().info('伺服器還沒準備好，等待中...')
            
        self.req = AddTwoInts.Request()

    def send_request(self, a, b):
        self.req.a = a
        self.req.b = b
        # call_async 會把請求發送出去，並回傳一個「未來結果 (Future)」物件
        return self.cli.call_async(self.req)

def main(args=None):
    rclpy.init(args=args)
    client = MinimalClient()
    
    # 我們設計讓使用者可以在終端機輸入數字，沒輸入就預設算 3 + 4
    a = int(sys.argv[1]) if len(sys.argv) == 3 else 3
    b = int(sys.argv[2]) if len(sys.argv) == 3 else 4
    
    # 呼叫函數發送請求
    future = client.send_request(a, b)
    
    # 程式會暫停卡在這裡 (Block)，直到伺服器把結果傳回來為止！
    rclpy.spin_until_future_complete(client, future)
    
    # 取得結果並印出
    response = future.result()
    client.get_logger().info(f'伺服器回傳結果: {a} + {b} = {response.sum}')

    client.destroy_node()
    rclpy.shutdown()

if __name__ == '__main__':
    main()