import net, type_varint

proc readString*(stream: Socket): string =
    let s = stream.readVarint().int
    result = stream.recv(s)

proc writeString*(buf: var string, str: string) =
    buf = str & buf
    writeVarint(buf, str.len)