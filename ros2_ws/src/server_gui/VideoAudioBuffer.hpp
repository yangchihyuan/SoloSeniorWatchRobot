#ifndef __VIDEOAUDIOBUFFER_HPP__
#define __VIDEOAUDIOBUFFER_HPP__

#include <opencv2/opencv.hpp>

using std::array;
using std::vector;
using std::mutex;
using namespace cv;

struct VABuffer
{
    std::queue<Mat> vecframes;
    std::queue<short> AudioSignal;
};

class VideoAudioBuffer
{
public:
    void AddAFrame(Mat ANewFrame);
    void AddAudio(const short *pShort, long long sampleCount);
    void ReduceFrameBuffer(int uiReduceToCount);
    void ReduceAudioBuffer(int uiReduceToCount);
    VABuffer GetVideoAudioBuffer();

protected:
    uint uiFrameBufferSize = 300;
    uint uiSamepleSize = 160000;
    VABuffer mInternalBuffer;
    mutex mtx_video;
    mutex mtx_audio;
};

#endif
