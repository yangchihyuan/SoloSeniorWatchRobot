cmake_minimum_required(VERSION 3.8)
project(my_cpp_pkg)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

# 1. Build the executable (compile my_cpp_node.cpp into an executable named my_cpp_node)
add_executable(my_cpp_node src/my_cpp_node.cpp)

# Build the publisher and configure its dependencies
add_executable(my_cpp_pub src/my_cpp_pub.cpp)
ament_target_dependencies(my_cpp_pub rclcpp std_msgs)

# Build the subscriber and configure its dependencies
add_executable(my_cpp_sub src/my_cpp_sub.cpp)
ament_target_dependencies(my_cpp_sub rclcpp std_msgs)

# 2. Link the ROS 2 libraries (so the executable can use rclcpp features)
ament_target_dependencies(my_cpp_node rclcpp)

# 3. Install the executable (place the built file in the install directory so ros2 run can find it)
install(TARGETS
  my_cpp_node
  my_cpp_pub    # Add the publisher
  my_cpp_sub    # Add the subscriber
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
