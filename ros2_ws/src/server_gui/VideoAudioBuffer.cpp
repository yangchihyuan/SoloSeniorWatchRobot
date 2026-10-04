#include "VideoAudioBuffer.hpp"

VABuffer VideoAudioBuffer::GetVideoAudioBuffer()
{
    mtx_video.lock();
    mtx_audio.lock();
    VABuffer temp = mInternalBuffer;
    mtx_video.unlock();
    mtx_audio.unlock();
    return temp;
}

void VideoAudioBuffer::AddAFrame(Mat ANewFrame)
{
    mtx_video.lock();
    mInternalBuffer.vecframes.push(ANewFrame);
    ReduceFrameBuffer(uiFrameBufferSize);
    mtx_video.unlock();
}

void VideoAudioBuffer::AddAudio(const short *pShort, long long sampleCount)
{
    mtx_audio.lock();
    for (long long i = 0; i < sampleCount; i++)
    {
        mInternalBuffer.AudioSignal.push(pShort[i]);
    }
    ReduceAudioBuffer(uiSamepleSize);
    mtx_audio.unlock();
}

void VideoAudioBuffer::ReduceFrameBuffer(int uiReduceToCount)
{
    while (mInternalBuffer.vecframes.size() > uiReduceToCount)
    {
        mInternalBuffer.vecframes.pop();
    }
}

void VideoAudioBuffer::ReduceAudioBuffer(int uiReduceToCount)
{
    while (mInternalBuffer.AudioSignal.size() > uiReduceToCount)
    {
        mInternalBuffer.AudioSignal.pop();
    }
}