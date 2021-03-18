import net, strutils

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
        
proc toVarint*(buf: var string, n: uint64) =
    ## Write a varint to a stream.
    var value = n
    var b: seq[uint8] 
    while value >= 0x80'u64:
        b.add((value or 0x80).uint8)
        value = value shr 7
    b.add(value.uint8)

    buf = cast[string](b) & buf

proc readString*(stream: Socket): string =
    let s = stream.readVarint().int
    result = stream.recv(s)

proc readUnsignedShort*(stream: Socket): uint16 =
    let s = stream.recv(2)
    result = uint16(s[1]) or (uint16(s[0]) shl 8)


var socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
socket.bindAddr(Port(25565))
socket.listen()

#  10 00 D4 02
#  09 31 32 37
#  2E 30 2E 30
#  2E 31 63 DD
#  01 
#  ---
#  01 00

# size (0x10 -> 16)
# ID (0x00 -> handshake)
# protocol (0xD402 -> 340)
# string size (0x09 -> 9 symbols)
# ip (0x3132372E302E302E31 -> 127.0.0.1)
# port (0x63DD -> 25565)
# next state (0x01 -> status)
# --- 
# size (0x01 -> 1)
# ID (0x00 -> status)

# (if next_state == 2)
#  0C 00 0A
#  47 72 65 65
#  6E 48 65 6C
#  6C 6F

# size (0x0C -> 12)
# ID (0x00 -> login_start)
# string size (0x0A -> 10 symbols)
# nickname (0x477265656E48656C6C6F -> GreenHello)

var client: Socket
var address = ""
while true:
    socket.acceptAddr(client, address)
    echo("Client connected from: ", address)
    echo "size: " & $client.readVarint()
    echo "PackageID: " & $client.readVarint()
    echo "Protocol: " & $client.readVarint()
    echo "IP: " & $client.readString()
    echo "Port: " & $client.readUnsignedShort()
    echo "Next state: " & $client.readVarint()
    # request
    echo client.readVarint()
    echo client.readVarint()

    # var buf = ""
    # toString("""{
    #     "version": {
    #         "name": "1.12.2",
    #         "protocol": 340
    #     },
    #     "players": {
    #         "max": 100,
    #         "online": 5,
    #         "sample": [
    #             {
    #                 "name": "thinkofdeath",
    #                 "id": "4566e69f-c907-48ee-8d71-d7ba5aa00d20"
    #             }
    #         ]
    #     },
    #     "description": {
    #         "text": "Oaoaooammmmmm"
    #     },
    #     "favicon": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAEbElEQVR4nO1bPUgcQRR+o1vYiRb+LIcHqZSYpIipAiIEolGESKokkjpquhNsLG2Eu4Ah0SJJlRArUXLkx4BwCAEhpjCJqE1AOfa0SC5iY5G4KdbZ25md3dnZ2bkfzw9kd+a9efPeuzc/+2ZEwMOzA9OPvH9hwbd5y61RxO2jhKgJxLW5EqxOFVg/AueHCQr+rzP6ptDRxRvW02H8/uAfAAC4/ihFNPv8NAEAEUSA09CxZuRZFxL8CMBG46dXnSpgA52GsupCItgQYBlaDOMxWIZGYDxAUAecYWhRCcJjvtIgHAHmaJMKPUoGJLqcmKNNkMvlQF+sjUaDiMZyWBQiwG9d31yx/3K5XDB+UUS0rovKsiLAqTA9u2+ugDlSz248d8jk95TFwlgzinJdF5VlRYDPum6O1ANa7QK02mXX4TLTMWH2CBGu66KyXHMA3ts3x+KWkd3rAJ39gLZTYP7tsBppW2C2JwB+vLd5DrK7AADQ8vNOOIVLBNcqcHLldmhhMm1LBSICzO51Ntfe6bPNo0wLdQwXLkocAcj8/i662devI8op2Nno0kBpHUBX0A5p7B4m6Pl83lfh/Q+zvg7lDRNd133l0/otv3hO0PtmloQcWvXfAucOKLUCpQYyDIMYU62trQSDvfX1oB98nCPKzbG4b4d4vxAVP4/Om2S1mo0lsuYXKaCG6oCmVzqqfghoA5MvAQDg6+u7cHV4Hurq6giG4+NjokzTFybvkxI7+/17zM7504sM7ejoyC443/3qnBDd/rr4qTnFBcUOk3YAC3jixBMmXS4naM4Qp8Pdq44H2tByNByj6ifBqneAdFrcMAyl/Kp/IWkH6LpOlEXHO4//YENYJSFU/RBw7ZPpb4POh68I+u+3E/7f66Zpou0Um9aecH1b0ODlA+gcpjH0T6w9hciOxlzoGCcV2UoqyTydZJIQy09AtmEaYvkJ4fYVPwScxmcbpoXbq4uAIsEaAuNggPUEeCzUXjof4EVH26nCMNhKmmZ7IpA8l4Jj82SF30kUi87JOiuLALM9AWgLTPxertBEZ00XZh6Qk9vNy/ZrW+8TAABAyw76p2/gxc+GzqHLQT4CdvooiVYItk1fg72JL9Z7b+EddlaY/N5QextN2SpgG0y9lxsqfhmURfkvg7P3lB6dVX0EKNsHYMTjcdjd3Q3M71IQIaURoDwfsLa2Rhgtmg8gruoCRL4RIiJAn8owOzAme+xisSMgaAQODg5COp120XkRpOlTGV8FAE4dg0E5yBjyb+s0XiXS6XSodtHnAyTvF0if/wvmC878KnCSSYK+WGs/aZx5B/DyBeW/EZIEL1+gfB8ge7+Ae/4/d0iURZdJ6Qio9PsF0vkA3q2wcod0BOD7BRis+wX47gGL7rpfUGRIO4B3fI7pYY7Zi4FzB8gK4N0fwPQw9wwCQTJfcOY3QjxosvuAxsZGRaoVB5W/E5TMFxAOYOcDMkQ+oNyAdSvkA8h/68vleogyTZfOBzQE1VQxwuYD/gOR9BVhJcDLTAAAAABJRU5ErkJggg=="
    # }""")



    #TRY_SAVE_BUFFER
    # let s = client.readVarint()
    # echo "size: " & $s
    # let buf = client.recv(s.int)
    
    # for i in 0..<s.int:
    #     echo $(buf[i].uint8).toHex


    #DEBUG_STORY
    # while true:
    #     var b = ""
    #     var l = ""
    #     for i in 1..4:
    #         b = client.recv(1)
    #         if b == "":
    #             echo l
    #             break
    #         l = l & " " & b.tohex
    #     if b == "":
    #         echo "----end----"
    #         break
    #     else:
    #         echo l
    # echo client.recv(9)
    # echo cast[uint16](recv(client, 16))


