import net, strutils, parsecfg
import streams, base64
import types/types

proc faviconTo64(): string =
    let strm = newFileStream("favicon.png")
    let data = encode(strm.readAll)
    result = "data:image/png;base64," & data


var conf = loadConfig("server.cfg")
var s_address = (conf.getSectionValue("Server","address", "127.0.0.1"))
var s_port = Port((conf.getSectionValue("Server","port")).parseInt)

let favicon = faviconTo64()

echo "Creating socket"
var socket = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
echo "Bind to " & s_address & ":" & $s_port
socket.bindAddr(s_port, s_address)
echo "Listening... "
socket.listen()

var client: Socket
var address = ""
while true:
    socket.acceptAddr(client, address)
    echo("Client connected from: ", address)
    echo "size: " & $client.readVarint()
    echo "PackageID: " & $client.readVarint()
    echo "Protocol: " & $client.readVarint()
    var c_address = client.readString()
    var c_port = Port(client.readUnsignedShort())
    echo "Address: " & $c_address & ":" & $c_port
    echo "Next state: " & $client.readVarint()
    # request
    echo client.readVarint() # size
    echo client.readVarint() # status

    var buf = ""

    writeString(buf, """{
        "version": {
            "name": "1.12.2",
            "protocol": 340
        },
        "players": {
            "max": """ & conf.getSectionValue("Server","max_players", "0") & """,
            "online": 0,
            "sample": [
                {
                    "name": "thinkofdeath",
                    "id": "4566e69f-c907-48ee-8d71-d7ba5aa00d20"
                }
            ]
        },
        "description": {
            "text": """" & conf.getSectionValue("Server", "motd", "<unknow>") & """"
        },
        "favicon": """ & favicon & """
    }""")
    writeVarint(buf, 0)
    writeVarint(buf, buf.len)

    echo client.trySend(buf)



