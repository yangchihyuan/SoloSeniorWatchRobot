import rclpy
from rclpy.node import Node
from example_interfaces.srv import AddTwoInts # 匯入內建的相加服務格式

class MinimalService(Node):
    def __init__(self):
        super().__init__('minimal_service')
        # 建立服務：(服務格式, '服務名稱', 處理請求的回呼函數)
        self.srv = self.create_service(
            AddTwoInts, 'add_two_ints', self.add_two_ints_callback)
        self.get_logger().info('加法伺服器已啟動，等待請求中...')

    def add_two_ints_callback(self, request, response):
        # 當收到請求時，這個函數會被觸發
        # request 裡面有 a 和 b；我們把計算結果存入 response.sum
        response.sum = request.a + request.b
        self.get_logger().info(f'收到請求: 計算 {request.a} + {request.b}')
        
        # 必須回傳 response，系統才會把它送回給用戶端
        return response

def main(args=None):
    rclpy.init(args=args)
    node = MinimalService()
    rclpy.spin(node) # 讓伺服器停在這裡持續待命
    rclpy.shutdown()

if __name__ == '__main__':
    main()