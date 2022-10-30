module raknet

struct PacketQueue {
	mut:
		lowest UInt24
		highest UInt24
		queue map[UInt24][]byte
}

fn new_packet_queue() &PacketQueue {
	return &PacketQueue{queue: map[UInt24][]byte{}}
}

fn (mut queue PacketQueue) put(index UInt24, packet []byte) bool {
	if index < queue.lowest {
		return false
	}
	if index in queue.queue {
		return false
	}
	if index >= queue.highest {
		queue.highest = index + 1
	}
	queue.queue[index] = packet
	return true
}

fn (mut queue PacketQueue) fetch() [][]byte {
	mut packets := [][]byte{}
	mut index := queue.lowest
	mut packet := []byte{}
	for index < queue.highest {
		if !(index in queue.queue) {
			break
		}
		queue.queue.delete(index)
		packets.insert(packets.len, packet)
		index++
	}
	queue.lowest = index
	return packets
}

fn (mut queue PacketQueue) window_size() UInt24 {
	return queue.highest - queue.lowest
}