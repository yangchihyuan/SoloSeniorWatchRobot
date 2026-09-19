import socket
import struct

import cv2
import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import CompressedImage
from std_msgs.msg import UInt8MultiArray

class AndroidAVBridge(Node):
    """Receive length-prefixed JPEG and audio frames from an Android TCP client.

    Wire format for each stream:
    ``[4-byte unsigned big-endian payload length][payload bytes]``.
    """

    def __init__(self):
        super().__init__('android_av_bridge')
        self.vid_pub = self.create_publisher(
            CompressedImage, '/android/camera/compressed', 10)
        self.aud_pub = self.create_publisher(
            UInt8MultiArray, '/android/audio_buffer', 10)

        self.vid_listener = self._create_listener(5000)
        self.aud_listener = self._create_listener(5001)
        self.vid_conn = None
        self.aud_conn = None
        self.vid_buffer = bytearray()
        self.aud_buffer = bytearray()

        self.get_logger().info(
            'TCP servers started: video port 5000, audio port 5001')
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

    def _read_frames(self, connection, buffer, name):
        """Append available TCP bytes and return every complete framed payload."""
        try:
            while True:
                chunk = connection.recv(65536)
                if not chunk:
                    self.get_logger().info(f'{name} TCP client disconnected')
                    connection.close()
                    return None, []
                buffer.extend(chunk)
                if len(chunk) < 65536:
                    break
        except BlockingIOError:
            pass
        except ConnectionError as error:
            self.get_logger().warn(f'{name} TCP connection error: {error}')
            connection.close()
            return None, []

        frames = []
        while len(buffer) >= 4:
            payload_size = struct.unpack('!I', buffer[:4])[0]
            if payload_size > 10 * 1024 * 1024:
                self.get_logger().error(f'{name} frame is too large: {payload_size} bytes')
                connection.close()
                return None, []
            if len(buffer) < 4 + payload_size:
                break
            frames.append(bytes(buffer[4:4 + payload_size]))
            del buffer[:4 + payload_size]
        return connection, frames

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
            self.vid_conn, video_frames = self._read_frames(
                self.vid_conn, self.vid_buffer, 'Video')
            for vid_data in video_frames:
                np_arr = np.frombuffer(vid_data, np.uint8)
                cv_image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
                if cv_image is not None:
                    cv2.imshow('Server View', cv_image)
                    cv2.waitKey(1)

                img_msg = CompressedImage()
                img_msg.format = 'jpeg'
                img_msg.data = list(vid_data)
                self.vid_pub.publish(img_msg)

        if self.aud_conn is not None:
            self.aud_conn, audio_frames = self._read_frames(
                self.aud_conn, self.aud_buffer, 'Audio')
            for aud_data in audio_frames:
                aud_msg = UInt8MultiArray()
                aud_msg.data = list(aud_data)
                self.aud_pub.publish(aud_msg)

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
    finally:
        node.destroy_node()
        cv2.destroyAllWindows()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
