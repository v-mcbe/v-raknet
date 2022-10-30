module raknet

import bytes

type UInt24 = u32

fn read_uint24(mut b &bytes.Buffer) UInt24 {
	ba := b.read_byte()
	bb := b.read_byte()
	bc := b.read_byte()
	return UInt24(ba) | (UInt24(bb) << 8) | (UInt24(bc) << 16) 
}

fn write_uint24(mut b &bytes.Buffer, value UInt24) {
	b.write_byte(byte(value))
	b.write_byte(byte(value >> 8))
	b.write_byte(byte(value >> 16))
} 