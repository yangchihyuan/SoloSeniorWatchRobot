import socket
import struct

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from sensor_msgs.msg import CompressedImage
from std_msgs.msg import UInt8MultiArray
from .robot_command_proto import ProtoDecodeError, decode_robot_to_server_message


FRAME_HEAD = b'BeginOfADataFrame'
FRAME_TAIL = b'EndOfADataFrame'
MAX_FRAME_SIZE = 10 * 1024 * 1024

class AndroidAVBridge(Node):
    """Bridge the unchanged Android TCP protocol to ROS 2 topics.

    Android's image stream is delimiter-framed and contains a little-endian
    length followed by a RobotToServerMessage protobuf.  Its audio stream is
    raw PCM16 and has no protobuf or frame header.
    """

    def __init__(self):
        super().__init__('android_av_bridge')
        self.vid_pub = self.create_publisher(
            CompressedImage, '/android/camera/compressed', 10)
        self.aud_pub = self.create_publisher(
            UInt8MultiArray, '/android/audio_buffer', 10)

        # Keep the ports used by the existing Android app unchanged.
        self.vid_listener = self._create_listener(8895)
        self.aud_listener = self._create_listener(8897)
        self.vid_conn = None
        self.aud_conn = None
        self.vid_buffer = bytearray()
        self.aud_buffer = bytearray()

        self.get_logger().info(
            'TCP servers started: Android image port 8895, audio port 8897')
        self.timer = self.create_timer(0.01, self.receive_data)

    @staticmethod
    def _create_listener(port):
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('0.0.0.0', port))
        listener.listen(1)
        listener.setblocking(False)
        return listener

    def _accept_connection(self, listener, name):
        try:
            connection, address = listener.accept()
            connection.setblocking(False)
            self.get_logger().info(f'{name} TCP client connected: {address}')
            return connection
        except BlockingIOError:
            return None

    def _read_available(self, connection, buffer, name):
        """Append all currently available bytes to a stream buffer."""
        try:
            while True:
                chunk = connection.recv(65536)
                if not chunk:
                    self.get_logger().info(f'{name} TCP client disconnected')
                    connection.close()
                    return None
                buffer.extend(chunk)
                if len(chunk) < 65536:
                    break
        except BlockingIOError:
            pass
        except ConnectionError as error:
            self.get_logger().warn(f'{name} TCP connection error: {error}')
            connection.close()
            return None

        return connection

    def _read_image_frames(self):
        """Extract complete Android image protobuf payloads from ``vid_buffer``."""
        frames = []
        while True:
            head_index = self.vid_buffer.find(FRAME_HEAD)
            if head_index < 0:
                # Keep a possible partial header for the next TCP read.
                del self.vid_buffer[:-len(FRAME_HEAD) + 1]
                break
            if head_index:
                del self.vid_buffer[:head_index]
            header_size = len(FRAME_HEAD) + 4
            if len(self.vid_buffer) < header_size:
                break

            payload_size = struct.unpack('<I', self.vid_buffer[
                len(FRAME_HEAD):header_size])[0]
            if payload_size > MAX_FRAME_SIZE:
                raise ProtoDecodeError(f'image frame is too large: {payload_size}')
            frame_size = header_size + payload_size + len(FRAME_TAIL)
            if len(self.vid_buffer) < frame_size:
                break
            tail_start = header_size + payload_size
            if self.vid_buffer[tail_start:frame_size] != FRAME_TAIL:
                # Drop one byte and resynchronise on the next header.
                del self.vid_buffer[:1]
                continue
            frames.append(bytes(self.vid_buffer[header_size:tail_start]))
            del self.vid_buffer[:frame_size]
        return frames

    def receive_data(self):
        if self.vid_conn is None:
            self.vid_conn = self._accept_connection(self.vid_listener, 'Video')
            if self.vid_conn is not None:
                self.vid_buffer.clear()
        if self.aud_conn is None:
            self.aud_conn = self._accept_connection(self.aud_listener, 'Audio')
            if self.aud_conn is not None:
                self.aud_buffer.clear()

        if self.vid_conn is not None:
            self.vid_conn = self._read_available(
                self.vid_conn, self.vid_buffer, 'Video')
            for protobuf_data in self._read_image_frames():
                try:
                    vid_data, seconds, nanos = decode_robot_to_server_message(
                        protobuf_data)
                except ProtoDecodeError as error:
                    self.get_logger().warning(
                        f'Invalid Android image protobuf: {error}')
                    continue
                img_msg = CompressedImage()
                img_msg.format = 'jpeg'
                img_msg.header.stamp.sec = seconds
                img_msg.header.stamp.nanosec = nanos
                img_msg.data = list(vid_data)
                self.vid_pub.publish(img_msg)

        if self.aud_conn is not None:
            self.aud_conn = self._read_available(
                self.aud_conn, self.aud_buffer, 'Audio')
            # Android sends raw PCM16 on 8897.  Publish each available chunk;
            # the GUI keeps a trailing odd byte until the next callback.
            if self.aud_buffer:
                aud_msg = UInt8MultiArray()
                aud_msg.data = list(self.aud_buffer)
                self.aud_pub.publish(aud_msg)
                self.aud_buffer.clear()

    def destroy_node(self):
        for connection in (
                self.vid_conn, self.aud_conn,
                self.vid_listener, self.aud_listener):
            if connection is not None:
                connection.close()
        super().destroy_node()

def main(args=None):
    rclpy.init(args=args)
    node = AndroidAVBridge()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()

if __name__ == '__main__':
    main()
