module raknet

import time

struct ResendMap {
	unacknowledged map[UInt24]ResendRecord
	delays map[time.Time]time.Duration
}

struct ResendRecord {
	mut:
		pk Packet
		timestamp time.Time	
}
