module raknet

import vtils.bytes
import encoding.binary

const (
	bit_flag_datagram = 0x80
	bit_flag_ack = 0x40
	bit_flag_nack = 0x20

	split_flag = 0x10
)

enum Reliability {
	unreliable
	unreliable_sequenced
	reliable
	reliable_ordered
	reliable_sequenced
}

struct Packet {
	mut:
		reliability byte

		content []byte
		message_index UInt24
		sequence_index UInt24
		order_index UInt24

		split bool
		split_count u32
		split_index u32
		split_id u16
}

fn (mut packet Packet) write(mut buf bytes.Buffer) {
	mut header := packet.reliability << 5
	if packet.split {
		header |= split_flag
	}
	buf.write_byte(header)
	binary.big_endian_put_u16(mut buf.buf, u16(packet.content.len) << 3)
	if packet.reliable() {
		write_uint24(mut buf, packet.message_index)
	}
	if packet.sequenced() {
		write_uint24(mut buf, packet.sequence_index)
	}
	if packet.sequenced_ordered() {
		write_uint24(mut buf, packet.order_index)
		buf.write_byte(0)
	}
	if packet.split {
		binary.big_endian_put_u32(mut buf.buf, packet.split_count)
		binary.big_endian_put_u16(mut buf.buf, packet.split_id)
		binary.big_endian_put_u32(mut buf.buf, packet.split_index)
	}
	buf.write(packet.content)
}

fn (mut packet Packet) read(mut buf bytes.Buffer) ! {
	mut header := buf.read_byte()
	packet.split = (header & split_flag) != 0
	packet.reliability = (header & 224) >> 5
	mut packet_length := binary.big_endian_u16(buf.buf)
	packet_length >>= 3
	if packet_length == 0 {
		error('invalid packet length: cannot be 0')
	}

	if packet.reliable() {
		packet.message_index = read_uint24(mut buf)
	}

	if packet.sequenced() {
		packet.sequence_index = read_uint24(mut buf)
	}

	if packet.sequenced_ordered() {
		packet.order_index = read_uint24(mut buf)
		buf.read_byte()
	}
	
	if packet.split {
		packet.split_count = binary.big_endian_u32(buf.buf)
		packet.split_id = binary.big_endian_u16(buf.buf)
		packet.split_index = binary.big_endian_u32(buf.buf)
	}

	packet.content = []byte{len: int(packet_length)}
	n := buf.read(mut packet.content)
	if n != packet_length {
		error('not enough data in packet')
	}
}

fn (mut packet Packet) reliable() bool {
	match packet.reliability {
		byte(Reliability.reliable),
		byte(Reliability.reliable_ordered),
		byte(Reliability.reliable_sequenced) {
			return true
		} else {}
	}
	return false
}

fn (mut packet Packet) sequenced_ordered() bool {
	match packet.reliability {
		byte(Reliability.unreliable_sequenced),
		byte(Reliability.reliable_ordered),
		byte(Reliability.reliable_sequenced) {
			return true
		} else {}
	}
	return false
}

fn (mut packet Packet) sequenced() bool {
	match packet.reliability {
		byte(Reliability.unreliable_sequenced),
		byte(Reliability.reliable_sequenced) {
			return true
		} else {}
	}
	return false
}
