import Foundation

// Appends a line to Documents/events.log, where test/run.sh reads it from the simulator.
func record(_ event: String) {
  NSLog("PROBE: %@", event)
  let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("events.log")
  let line = Data((event + "\n").utf8)
  if let handle = try? FileHandle(forWritingTo: file) {
    handle.seekToEndOfFile()
    handle.write(line)
    handle.closeFile()
  } else {
    try? line.write(to: file)
  }
}
