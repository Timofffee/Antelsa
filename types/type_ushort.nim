import net

proc readUnsignedShort*(stream: Socket): uint16 =
    let s = stream.recv(2)
    result = uint16(s[1]) or (uint16(s[0]) shl 8)