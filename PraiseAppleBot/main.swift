import Cocoa

class IRCMessage {
    var prefix: String?
    var command = ""
    var args: [String] = []
    
    init(line: String) {
        var split = line.componentsSeparatedByString(" ")
        
        if line[line.startIndex] == ":" {
            prefix = split.removeFirst()
        }
        
        command = split.removeFirst()
        
        // The rest of the split are args, but still need to check for the possible final : type arg, and merge into one string
        while (!split.isEmpty) {
            if (split[0][split[0].startIndex] == ":") {
                // Collect the remaining split into one arg
                args.append(split.joinWithSeparator(" "))
                split.removeAll()
            } else {
                args.append(split.removeFirst())
            }
        }
        
    }
}

// Might as well just hardcode the damn things
let cr = [UInt8]("\r".utf8)[0]
let lf = [UInt8]("\n".utf8)[0]

// Set up IRC thing?
let addr =  "chat.freenode.net"
let port = 6667

let nick = "PraiseAppleBot"
let channels = ["#osuosc"]
let greeting = "Praise Apple!"

var inp :NSInputStream?
var out :NSOutputStream?

NSStream.getStreamsToHostWithName(addr, port: port, inputStream: &inp, outputStream: &out)

let inputStream = inp!
let outputStream = out!

inputStream.open()
outputStream.open()

func sendMessageStr(message: String) {
    let withEndings = "\(message)\r\n"
    let data = withEndings.dataUsingEncoding(NSUTF8StringEncoding)!
    outputStream.write(UnsafePointer(data.bytes), maxLength: data.length)
}

func handleServerCommand(message: IRCMessage, outputStream: NSOutputStream) {
    print("\(message.prefix), \(message.command), \(message.args)")
    switch (message.command) {
    case "PING":
        print("Got PING: \(message.args[0])")
        sendMessageStr("PONG \(message.args[0])")
    case "376": //MOTD
        for channel in channels {
            sendMessageStr("JOIN \(channel)")
            sendMessageStr("PRIVMSG \(channel) :\(greeting)")
        }
    case "PRIVMSG":
        if (message.args[1].hasPrefix(":.praise")) {
            // Reply to channel or sender
            if (message.args[0].hasPrefix("#")) {
                sendMessageStr("PRIVMSG \(message.args[0]) :\(greeting)")
            } else {
                // Reply to sender. Nick is first part of prefix, minus the :
                var user = message.prefix!.componentsSeparatedByString("!")[0]
                user.removeAtIndex(user.startIndex)
                sendMessageStr("PRIVMSG \(message.args[0]) :\(greeting)")
            }
        }
    default:
        return
    }
}

// Send initial auth stuff
sendMessageStr("NICK \(nick)")
sendMessageStr("USER \(nick) +iw * :LibreWulf's Worst Bot")

var bytes: [UInt8] = []

// Main event loop
while true {
    while inputStream.hasBytesAvailable {
        var byte: UInt8 = 0
        inputStream.read(&byte, maxLength: 1)
        
        if (byte == cr) {
            // Consume and check for line feed
            inputStream.read(&byte, maxLength: 1)
            assert(byte == lf)
            
            // Parse the line into a string, then run message handler
            let line = String(bytes: bytes, encoding: NSUTF8StringEncoding)!
            print(line)
            handleServerCommand(IRCMessage(line: line), outputStream: outputStream)
            
            // Clear the byte array for future use
            bytes.removeAll()
        } else {
            bytes.append(byte)
        }
    }
}
