module raknet

import vtils.bytes
import encoding.binary
import vtils.binary as bin

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

fn (mut packet Packet) read(mut buf bytes.Buffer) ? {
	mut header := buf.read_byte()
	packet.split = (header & split_flag) != 0
	packet.reliability = (header & 224) >> 5
	mut packet_length := u16(0)
	bin.read_u16_drop(mut buf.buf, bin.BigEndian{}, mut packet_length)
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
		bin.read_u32_drop(mut buf.buf, bin.BigEndian{}, mut packet.split_count)
		bin.read_u16_drop(mut buf.buf, bin.BigEndian{}, mut packet.split_id)
		bin.read_u32_drop(mut buf.buf, bin.BigEndian{}, mut packet.split_index)
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

enum PacketKind {
	packet_range
	packet_single
}

struct Acknowledgement {
	mut:
		packets []UInt24
}

fn (mut ack Acknowledgement) write(mut b bytes.Buffer, mtu u16) int {
	mut n := 0
	mut packets := ack.packets.clone()
	if packets.len == 0 {
		binary.big_endian_put_u16(mut b.buf, 0)
		return 0
	}
	mut buffer := bytes.new_buffer([]byte{})
	ack.packets.sort()

	mut first_packet_in_range := UInt24(0)
	mut last_packet_in_range := UInt24(0)
	mut record_count := i16(0)

	for index, packet in ack.packets {
		if buffer.buf.len >= int(mtu - 10) {
			break
		}
		n++
		if index == 0 {
			first_packet_in_range = packet
			last_packet_in_range = packet
			continue
		}
		if packet == last_packet_in_range + 1 {
			last_packet_in_range = packet
			continue
		} else {
			if first_packet_in_range == last_packet_in_range {
				buffer.write_byte(byte(PacketKind.packet_single))
			} else {
				write_uint24(mut buffer, first_packet_in_range)

				first_packet_in_range = packet
				last_packet_in_range = packet
			}
			record_count++
		}
	}

	if first_packet_in_range == last_packet_in_range {
		buffer.write_byte(byte(PacketKind.packet_single))
		write_uint24(mut buffer, first_packet_in_range)
	} else {
		buffer.write_byte(byte(PacketKind.packet_range))
		write_uint24(mut buffer, first_packet_in_range)
		write_uint24(mut buffer, last_packet_in_range)
	}
	record_count++
	binary.big_endian_put_u16(mut b.buf, u16(record_count))
	b.write(buffer.buf)
	return n
}

const max_acknowledgement_packets = 8192 

fn (mut ack Acknowledgement) read(mut b bytes.Buffer) ? {
	mut record_count := i16(0)
	bin.read_i16_drop(mut b.buf, bin.BigEndian{}, mut record_count)
	for i := i16(0); i < record_count; i++ {
		mut record_type := b.read_byte()
		match record_type {
			i16(PacketKind.packet_range) {
				mut start := read_uint24(mut b)
				mut end := read_uint24(mut b)
				for pack := start; pack <= end; pack++ {
					ack.packets.insert(ack.packets.len, pack)
					if ack.packets.len > max_acknowledgement_packets {
						error('maximum amount of packets in acknowledgement exceeded')
					}
				}
			}
			i16(PacketKind.packet_single) {
				mut packet := read_uint24(mut b)
				ack.packets.insert(ack.packets.len, packet)
				if ack.packets.len > max_acknowledgement_packets {
					error('maximum amount of packets in acknowledgement exceeded')
				}
			}
			else {}
		}
	}
}