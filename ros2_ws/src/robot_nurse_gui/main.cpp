#include "mainwindow.h"
#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QTimer>
#include <ament_index_cpp/get_package_share_directory.hpp>
#include <rclcpp/rclcpp.hpp>
#include <utility_time.hpp>
#include <csignal>
#include <fstream>
#include <string>
#include "ThreadLLM.hpp"
#include <csignal>

int main(int argc, char *argv[])
{
    // 1. Initialize ROS 2 (it reads the required arguments but does not remove them from argc/argv)
    rclcpp::init(argc, argv);

    // 2. Use the built-in ROS 2 utility to remove all ROS-specific arguments (--ros-args, -r, etc.)
    std::vector<std::string> clean_args = rclcpp::remove_ros_arguments(argc, argv);
    std::vector<char*> qt_argv;
    for (auto& arg : clean_args) {
        qt_argv.push_back(const_cast<char*>(arg.c_str()));
    }
    int qt_argc = qt_argv.size();

    // 3. Initialize QApplication with the cleaned arguments
    QApplication app(qt_argc, qt_argv.data());

//    rclcpp::init(argc, argv);
//    QApplication app(argc, argv);
    const QString packageShareDirectory = QString::fromStdString(
        ament_index_cpp::get_package_share_directory("robot_nurse_gui"));
    QDir::setCurrent(packageShareDirectory);
    auto rosNode = rclcpp::Node::make_shared("robot_nurse_gui");
    QCoreApplication::setApplicationName("SoloSeniorWatchRobot");
    QCoreApplication::setApplicationVersion("2026.10.04");
    //It does not work. My application does not have a icon.
//    app.setWindowIcon(QIcon(":/ZenboNurse.png"));

    // Suppose the icon is located in the share directory of the package
    QString iconPath = packageShareDirectory + "/SoloSeniorWatchRobot.png";
    app.setWindowIcon(QIcon(iconPath));

    QCommandLineParser parser;
    parser.setApplicationDescription("Solo Senior Watch Robot");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument("setting-file", "JSON settings file (defaults to json/Setting.json)");
    QString home_directory = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);

    QCommandLineOption SettingFileOption("SettingFile", "Setting File", "string", "Setting.json");
    parser.addOption(SettingFileOption);

    // ROS 2 launch appends arguments such as `--ros-args -r __node:=...`.
    // They are consumed by rclcpp, but Qt's command-line parser also sees
    // them and reports them as unknown options. Parse only this app's args.
    QStringList appArguments = app.arguments();
    const int rosArgsIndex = appArguments.indexOf("--ros-args");
    if (rosArgsIndex >= 0) {
        appArguments = appArguments.mid(0, rosArgsIndex);
    }
    parser.process(appArguments);

    QString strSetting = "json/Setting.json";
    if (parser.isSet(SettingFileOption)) {
        strSetting = parser.value(SettingFileOption);
        qDebug() << "Setting file is:" << strSetting;
    } else if (!parser.positionalArguments().isEmpty()) {
        strSetting = parser.positionalArguments().constFirst();
        qDebug() << "Setting file is:" << strSetting;
    }

    if (!QFileInfo::exists(strSetting)) {
        qCritical() << "Setting file does not exist:" << strSetting
                    << "(working directory:" << QDir::currentPath() << ")";
        rclcpp::shutdown();
        return EXIT_FAILURE;
    }

    MainWindow w(rosNode);
    w.setSettingFile(strSetting);
    w.startThreads();

    Setting msetting;
    LoadJSONFile(msetting, strSetting.toStdString());

    // Hide the mouse cursor globally for the application
    //debug
    cout << "bHideCursor: " << msetting.bHideCursor << endl;
    if (msetting.bHideCursor) {
        app.setOverrideCursor(Qt::BlankCursor);
    }
    // 2026/05/20 How to enable the cursor again? app.restoreOverrideCursor();
    // How to call this function in the MainWindow when the user clicks a button to show/hide the cursor? You can use a signal-slot mechanism to achieve this. For example, you can define a slot in your MainWindow class that toggles the cursor visibility and connect it to a button click signal.
    // Can I only override cursor for a specific window instead of the whole application? Yes, you can set the cursor for a specific window by calling setCursor() on that window instance. For example, if you want to hide the cursor only in the MainWindow, you can do something like this:

    w.show();

    // Qt owns the GUI event loop.  Periodically process ROS callbacks without
    // blocking it; subscriptions can be added to rosNode incrementally.
    QTimer rosTimer;
    QObject::connect(&rosTimer, &QTimer::timeout, [&rosNode]() {
        rclcpp::spin_some(rosNode);
    });
    rosTimer.start(10);

    const int exitCode = app.exec();
    rclcpp::shutdown();
    return exitCode;
}
