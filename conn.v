module raknet

import vtils.bytes
import net
import sync

const (
	current_protocol = byte(11)
	max_mtu_size = 1400
	max_window_size = 2048
)

struct StructChan {}

struct Conn {
	mut:
		rtt int

		closing int

		conn net.UdpConn
		addr string
		limits bool

		once sync.Once
		closed chan StructChan
		connected chan StructChan
		close fn()

		buf bytes.Buffer

		ack_buf bytes.Buffer
		nack_buf bytes.Buffer

		pk &Packet

		seq UInt24
		order_index UInt24
		message_index UInt24
		split_id u32

		mtu_size u16

		splits map[u16][][]byte

		win DatagramWindow

		ack_slice []UInt24

		packet_queue PacketQueue
		packets chan bytes.Buffer
}