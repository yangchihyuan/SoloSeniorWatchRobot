#include "mainwindow.h"
#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
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
    rclcpp::init(argc, argv);
    QApplication app(argc, argv);
    const QString packageShareDirectory = QString::fromStdString(
        ament_index_cpp::get_package_share_directory("robot_nurse_gui"));
    QDir::setCurrent(packageShareDirectory);
    auto rosNode = rclcpp::Node::make_shared("robot_nurse_gui");
    QCoreApplication::setApplicationName("Robot Nurse Helper");
    QCoreApplication::setApplicationVersion("2026.07.01");
    //It does not work. My application does not have a icon.
    app.setWindowIcon(QIcon(":/ZenboNurse.png"));

    QCommandLineParser parser;
    parser.setApplicationDescription("Robot Nurse Helper");
    parser.addHelpOption();
    parser.addVersionOption();
    QString home_directory = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);

    QCommandLineOption SettingFileOption("SettingFile", "Setting File", "string", "Setting.json");
    parser.addOption(SettingFileOption);

    parser.process(app);

    QString strSetting;
    if (parser.isSet(SettingFileOption)) {
        strSetting = parser.value(SettingFileOption);
        qDebug() << "Setting file is:" << strSetting;
    }

    MainWindow w;
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
