#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"

using std::placeholders::_1; // 為了綁定回呼函數的參數

class MyCppSubscriber : public rclcpp::Node
{
public:
  MyCppSubscriber() : Node("my_cpp_subscriber")
  {
    // 建立訂閱者，並將收到的訊息綁定到 topic_callback 處理
    subscription_ = this->create_subscription<std_msgs::msg::String>(
      "robot_news", 10, std::bind(&MyCppSubscriber::topic_callback, this, _1));
  }

private:
  // 當收到訊息時會觸發這個函數
  void topic_callback(const std_msgs::msg::String & msg) const
  {
    RCLCPP_INFO(this->get_logger(), "收到廣播啦！內容是: '%s'", msg.data.c_str());
  }

  rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
};

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<MyCppSubscriber>());
  rclcpp::shutdown();
  return 0;
}