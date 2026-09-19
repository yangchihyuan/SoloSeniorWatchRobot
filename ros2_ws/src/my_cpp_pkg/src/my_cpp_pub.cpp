#include <chrono>
#include <functional>
#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp" // 引入字串訊息的標頭檔

using namespace std::chrono_literals;

class MyCppPublisher : public rclcpp::Node
{
public:
  MyCppPublisher() : Node("my_cpp_publisher"), count_(0)
  {
    // 建立發布者：(訊息型態, "頻道名稱", 儲列大小)
    publisher_ = this->create_publisher<std_msgs::msg::String>("robot_news", 10);
    
    // 建立計時器，每 1000 毫秒執行一次 timer_callback
    timer_ = this->create_wall_timer(
      1000ms, std::bind(&MyCppPublisher::timer_callback, this));
  }

private:
  void timer_callback()
  {
    auto message = std_msgs::msg::String();
    message.data = "C++ 機器人狀態更新：正常！ (編號: " + std::to_string(count_++) + ")";
    RCLCPP_INFO(this->get_logger(), "發布: '%s'", message.data.c_str());
    publisher_->publish(message); // 發送訊息
  }

  rclcpp::TimerBase::SharedPtr timer_;
  rclcpp::Publisher<std_msgs::msg::String>::SharedPtr publisher_;
  size_t count_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<MyCppPublisher>());
  rclcpp::shutdown();
  return 0;
}