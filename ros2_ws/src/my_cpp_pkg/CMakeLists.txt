cmake_minimum_required(VERSION 3.8)
project(my_cpp_pkg)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

# 1. 產生執行檔 (把 my_cpp_node.cpp 編譯成名為 my_cpp_node 的執行檔)
add_executable(my_cpp_node src/my_cpp_node.cpp)

# 發布者的編譯與依賴
add_executable(my_cpp_pub src/my_cpp_pub.cpp)
ament_target_dependencies(my_cpp_pub rclcpp std_msgs)

# 訂閱者的編譯與依賴
add_executable(my_cpp_sub src/my_cpp_sub.cpp)
ament_target_dependencies(my_cpp_sub rclcpp std_msgs)

# 2. 連結 ROS2 函式庫 (讓執行檔可以使用 rclcpp 的功能)
ament_target_dependencies(my_cpp_node rclcpp)

# 3. 安裝執行檔 (告訴系統把編譯好的檔案放到 install 目錄，讓 ros2 run 能找到)
install(TARGETS
  my_cpp_node
  my_cpp_pub    # 新增發布者
  my_cpp_sub    # 新增訂閱者  
  DESTINATION lib/${PROJECT_NAME}
)


if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
