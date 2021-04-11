import net

proc readVarint*(stream: Socket): int64 =
    ## Read a varint from a stream. Returns a 64-bit unsigned integer, which you
    ## should cast to the expected type.
    var
        count = 0

    result = 0

    while true:
        if count == 5:
            raise newException(Exception, "invalid varint (>= 5 bytes)")

        let b = uint64(stream.recv(1)[0])

        result = result or ((b and 0x7f).int64 shl (7 * count))

        if (b and 0x80) == 0:
            break

        inc(count)

proc writeVarint*(buf: var string, val: int) =
    ## Write a varint to a stream.
    var value = val.uint64
    var b: seq[uint8]
    while value >= 0x80'u64:
        b.add((value or 0x80).uint8)
        value = value shr 7
    b.add(value.uint8)

    buf = cast[string](b) & buf