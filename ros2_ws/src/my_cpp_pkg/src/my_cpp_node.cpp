#include "rclcpp/rclcpp.hpp"

// 繼承 rclcpp::Node 來建立我們的節點類別
class MyCppNode : public rclcpp::Node
{
public:
  // 建構子，初始化節點名稱為 "hello_cpp_node"
  MyCppNode() : Node("hello_cpp_node")
  {
    RCLCPP_INFO(this->get_logger(), "你好！我的第一個 C++ 節點啟動了！");
    
    // 建立計時器，每 1 秒 (1000 毫秒) 執行一次 timer_callback
    timer_ = this->create_wall_timer(
      std::chrono::milliseconds(1000),
      std::bind(&MyCppNode::timer_callback, this));
  }

private:
  void timer_callback()
  {
    RCLCPP_INFO(this->get_logger(), "C++ 節點持續運作中...");
  }
  
  rclcpp::TimerBase::SharedPtr timer_;
};

int main(int argc, char * argv[])
{
  // 初始化 ROS2 通訊
  rclcpp::init(argc, argv);
  
  // 建立節點實體並讓它持續運轉 (spin)
  rclcpp::spin(std::make_shared<MyCppNode>());
  
  // 關閉並清理
  rclcpp::shutdown();
  return 0;
}
