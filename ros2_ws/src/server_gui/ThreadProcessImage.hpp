#ifndef ThreadProcessImage_hpp
#define ThreadProcessImage_hpp

#include <QThread>
#include <QTcpServer>
#include <QTcpSocket>
#include <QDebug>
#include <iostream>
#include <filesystem>
#include <mutex>
#include <thread>
#include <condition_variable>
#include <atomic>
#include <chrono>
#include "ThreadSafeQueue.hpp"
#include "SendMessageManager.hpp"
#include "ActionOption.hpp"
#include <opencv2/opencv.hpp>

#include "Setting.hpp"
#include "VideoAudioBuffer.hpp"

struct DataFrame;

// EmotiEffLib
#include "emotiefflib/facial_analysis.h"

#ifdef USE_GPU
#include "libmp_gpu.h"
#else
#include "libmp.h"
#endif

#ifdef USE_dlib
#include <dlib/dnn.h>
#include <dlib/gui_widgets.h>
// #include <dlib/clustering.h>
#include <dlib/string.h>
#include <dlib/image_io.h>
#include <dlib/image_processing/frontal_face_detector.h>
#include <dlib/image_processing.h>
#include <dlib/opencv.h> // Essential for cv_image
#endif

// Yolo11pse
#include "Yolo11Pose.hpp"

// InspireFace
#include "inspireface.h"
#include "herror.h" // Required to use HSUCCEED

// using namespace std;
using std::array;
using std::vector;
using namespace cv;
extern int is_dancing;

class ThreadProcessImage : public QThread
{
    Q_OBJECT

public:
    ThreadProcessImage();
    ~ThreadProcessImage();

    bool b_HumanPoseEstimation = false;
    bool b_WhileLoop = true;
    bool bSaveTransmittedImage = false;
    std::atomic<bool> bSaveRequestedPhoto{false};
    std::string requestedPhotoPrefix;
    bool m_bRecognizeFacialExpression = true;
    string ImageSaveDirectory = ""; // default value is empty, which means not saving images

    SendMessageManager *pSendMessageManager;
    ThreadSafeQueue<DataFrame> DataFrames_queue;

    bool bNewoutFrame = false;
    void NotifyEvent(string description, chrono::time_point<chrono::system_clock> timestamp, float yaw = 0.0, float pitch = 0.0);

    ActionOption action_option;
    Mat getOutFrame();
    Mat getLatestFrame();

    string GetPatientGender();
    int GetPatientAge();
    //    void SetSettingFile(const QString &filePath);
    Setting *mpsetting = nullptr;
    VideoAudioBuffer *mpVideoAudioBuffer = nullptr;

protected:
    void run();
    std::shared_ptr<mediapipe::LibMP> libmp_face;
    std::shared_ptr<mediapipe::LibMP> libmp_hand;
    std::shared_ptr<mediapipe::LibMP> libmp_pose;

    std::mutex mtx_Task; // dlib::mutex has the same class mutex, so I add std::
    std::mutex mtx_UpdateOutFrame;
    bool m_bDirectoryCreated = false;
    bool m_bDirectoryCreated_VisualCompass = false;
    bool mbWatchPatient = true;
    Mat outFrame, tempFrame;
    cv::Rect GetBoundingBoxFromLandmarks(const std::vector<std::array<float, 3>> &normalized_landmarks, int img_width, int img_height);
    Mat CropRegion(Mat inputImage, std::vector<std::array<float, 3>> normalized_landmarks); // dlib has the vector and array, too.       //Crop the face region from inputImage according to the landmarks
    unique_ptr<EmotiEffLib::EmotiEffLibRecognizer> fer;

    Yolo11Pose yolo11pose;
    std::string mstr_captured_timestamp;

    // InspireFace
    HFSession session = {0};

    string msPatientGender = "Unknown"; // default
    int miPatientAge = -1;              // default -1 means unknown age

    std::chrono::time_point<std::chrono::system_clock> m_LastPersonDetectedTime;
    std::chrono::time_point<std::chrono::system_clock> m_LastCompassCheckTime;
    bool m_bTurningToZero = false;
    bool m_bBodyAtZero = false;
    string s_RobotModel = "Unknown"; // default value is Unknown. It will be set to "Kebbi" or "Zenbo" when the robot sends the first status message.
};

#endif
