#include "rclcpp/rclcpp.hpp"

// Inherit from rclcpp::Node to create our node class
class MyCppNode : public rclcpp::Node
{
public:
  // Constructor: initialize the node name to "hello_cpp_node"
  MyCppNode() : Node("hello_cpp_node")
  {
    RCLCPP_INFO(this->get_logger(), "你好！我的第一個 C++ 節點啟動了！");
    
    // Create a timer that runs timer_callback every second (1000 milliseconds)
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
  // Initialize ROS 2 communication
  rclcpp::init(argc, argv);
  
  // Create the node instance and keep it running (spin)
  rclcpp::spin(std::make_shared<MyCppNode>());
  
  // Shut down and clean up
  rclcpp::shutdown();
  return 0;
}
