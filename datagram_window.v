module raknet

import time

struct DatagramWindow {
	mut:
		lowest UInt24
		highest UInt24
		queue map[UInt24]time.Time
}

fn new_datagram_window() &DatagramWindow {
	return &DatagramWindow{queue: map[UInt24]time.Time{}}
}

fn (mut win DatagramWindow) new(index UInt24) bool {
	if index < win.lowest {
		return true
	}
	mut ok := false
	if index in win.queue {
		ok = true
	}
	return !ok
}

fn (mut win DatagramWindow) add(index UInt24) {
	if index >= win.highest {
		win.highest = index + 1
	}
	win.queue[index] = time.now()
}

fn (mut win DatagramWindow) shift() int {
	mut n := 0
	mut index := UInt24(0)
	for index = win.lowest; index < win.highest; index++ {
		if !(index in win.queue) {
			break
		}
		win.queue.delete(index)
		n++
	}
	win.lowest = index
	return n
}

fn (mut win DatagramWindow) missing(since time.Duration) []UInt24 {
	mut indices := []UInt24{}
	mut missing := false
	for index := int(win.highest) -1; index >= int(win.lowest); index-- {
		i := UInt24(u32(index))
		mut t := time.Time{}
		if i in win.queue {
			t = win.queue[i]
			if time.since(t) >= since {
				missing = true
			}
			continue			
		}
		if missing {
			indices.insert(indices.len, i)
			win.queue[i] = time.Time{}
		}
	}
	win.shift()
	return indices
}

fn (mut win DatagramWindow) size() UInt24 {
	return win.highest - win.lowest
}