import Compression
import Foundation

/// Apple LZFSE, raw stream (what `NSData.compressed(using: .lzfse)` writes), done through
/// `compression_stream` so that decompression can stop the moment the output exceeds a limit —
/// a backup is untrusted input, and a small file must not be able to allocate gigabytes.
public enum LZFSE {
    public enum Failure: Error, Equatable { case corrupt, tooLarge, empty }

    public static func compress(_ input: Data) throws -> Data {
        try run(COMPRESSION_STREAM_ENCODE, input, limit: Int.max)
    }

    /// Decompress; throws `.tooLarge` as soon as the output would exceed `limit` bytes.
    public static func decompress(_ input: Data, limit: Int) throws -> Data {
        try run(COMPRESSION_STREAM_DECODE, input, limit: limit)
    }

    private static func run(_ op: compression_stream_operation, _ input: Data, limit: Int) throws -> Data {
        guard !input.isEmpty else {
            if op == COMPRESSION_STREAM_DECODE { throw Failure.corrupt }
            return Data()
        }
        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPtr.deallocate() }
        guard compression_stream_init(streamPtr, op, COMPRESSION_LZFSE) == COMPRESSION_STATUS_OK else { throw Failure.corrupt }
        defer { compression_stream_destroy(streamPtr) }

        let chunk = 64 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
        defer { dst.deallocate() }
        var output = Data()

        try input.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
            streamPtr.pointee.src_ptr = src.bindMemory(to: UInt8.self).baseAddress!
            streamPtr.pointee.src_size = src.count
            var status: compression_status
            repeat {
                streamPtr.pointee.dst_ptr = dst
                streamPtr.pointee.dst_size = chunk
                status = compression_stream_process(streamPtr, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                guard status != COMPRESSION_STATUS_ERROR else { throw Failure.corrupt }
                let produced = chunk - streamPtr.pointee.dst_size
                if produced > 0 {
                    if output.count + produced > limit { throw Failure.tooLarge }
                    output.append(dst, count: produced)
                }
            } while status == COMPRESSION_STATUS_OK
        }
        return output
    }
}
