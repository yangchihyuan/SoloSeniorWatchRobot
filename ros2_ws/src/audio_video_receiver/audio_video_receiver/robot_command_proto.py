"""Small decoder for the RobotToServerMessage protobuf wire format.

The ROS Python environment on the target robot does not necessarily include
the Python protobuf runtime.  RobotToServerMessage only uses standard protobuf
wire types here, so decoding the fields needed by the bridge keeps the bridge
lightweight and avoids adding a system-wide dependency.
"""


class ProtoDecodeError(ValueError):
    """Raised when a protobuf payload is truncated or malformed."""


def _read_varint(payload, offset):
    value = 0
    shift = 0
    while offset < len(payload) and shift < 70:
        byte = payload[offset]
        offset += 1
        value |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return value, offset
        shift += 7
    raise ProtoDecodeError('invalid protobuf varint')


def _read_length_delimited(payload, offset):
    length, offset = _read_varint(payload, offset)
    end = offset + length
    if end > len(payload):
        raise ProtoDecodeError('truncated protobuf length-delimited field')
    return payload[offset:end], end


def _skip_field(payload, offset, wire_type):
    if wire_type == 0:
        _, offset = _read_varint(payload, offset)
        return offset
    if wire_type == 1:
        end = offset + 8
    elif wire_type == 2:
        _, end = _read_length_delimited(payload, offset)
    elif wire_type == 5:
        end = offset + 4
    else:
        raise ProtoDecodeError(f'unsupported protobuf wire type {wire_type}')
    if end > len(payload):
        raise ProtoDecodeError('truncated protobuf field')
    return end


def _decode_timestamp(payload):
    seconds = 0
    nanos = 0
    offset = 0
    while offset < len(payload):
        key, offset = _read_varint(payload, offset)
        field = key >> 3
        wire_type = key & 0x07
        if field in (1, 2) and wire_type == 0:
            value, offset = _read_varint(payload, offset)
            if field == 1:
                seconds = value
            else:
                nanos = value
        else:
            offset = _skip_field(payload, offset, wire_type)
    return seconds, nanos


def decode_robot_to_server_message(payload):
    """Return ``jpeg_data``, ``event_seconds`` and ``event_nanos``.

    The field numbers match Server/RobotCommand.proto's
    ``RobotToServerMessage`` declaration: event_time=1, jpegdatalength=2 and
    jpegdata=3.
    """
    jpeg_data = None
    event_seconds = 0
    event_nanos = 0
    declared_length = None
    offset = 0

    while offset < len(payload):
        key, offset = _read_varint(payload, offset)
        field = key >> 3
        wire_type = key & 0x07
        if field == 1 and wire_type == 2:
            timestamp, offset = _read_length_delimited(payload, offset)
            event_seconds, event_nanos = _decode_timestamp(timestamp)
        elif field == 2 and wire_type == 0:
            declared_length, offset = _read_varint(payload, offset)
        elif field == 3 and wire_type == 2:
            jpeg_data, offset = _read_length_delimited(payload, offset)
        else:
            offset = _skip_field(payload, offset, wire_type)

    if jpeg_data is None:
        raise ProtoDecodeError('RobotToServerMessage has no jpegdata field')
    if declared_length is not None and declared_length != len(jpeg_data):
        raise ProtoDecodeError(
            f'jpegdatalength={declared_length}, actual={len(jpeg_data)}')
    return jpeg_data, event_seconds, event_nanos
