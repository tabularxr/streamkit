import Foundation
import Compression

// MARK: - Compression Extensions

extension Data {
    
    /// Compress data using specified algorithm
    func compress(using algorithm: Algorithm) throws -> Data {
        return try perform(operation: .compression, algorithm: algorithm)
    }
    
    /// Decompress data using specified algorithm
    func decompress(using algorithm: Algorithm) throws -> Data {
        return try perform(operation: .decompression, algorithm: algorithm)
    }
    
    /// Compression algorithms
    enum Algorithm {
        case zlib
        case gzip
        case lzfse
        case lz4
        
        var algorithm: compression_algorithm {
            switch self {
            case .zlib: return COMPRESSION_ZLIB
            case .gzip: return COMPRESSION_ZLIB // Note: Using ZLIB for GZIP compatibility
            case .lzfse: return COMPRESSION_LZFSE
            case .lz4: return COMPRESSION_LZ4
            }
        }
    }
    
    private enum Operation {
        case compression
        case decompression
        
        var operation: compression_stream_operation {
            switch self {
            case .compression: return COMPRESSION_STREAM_ENCODE
            case .decompression: return COMPRESSION_STREAM_DECODE
            }
        }
    }
    
    private func perform(operation: Operation, algorithm: Algorithm) throws -> Data {
        guard !self.isEmpty else { return self }
        
        var streamPointer = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPointer.deallocate() }
        
        var stream = streamPointer.pointee
        var status = compression_stream_init(&stream, operation.operation, algorithm.algorithm)
        guard status != COMPRESSION_STATUS_ERROR else {
            throw CompressionError.compressionFailed("Failed to initialize compression stream")
        }
        defer { compression_stream_destroy(&stream) }
        
        let bufferSize = 65536 // 64KB buffer
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }
        
        var output = Data()
        self.withUnsafeBytes { bytes in
            let boundBytes = bytes.bindMemory(to: UInt8.self)
            stream.src_ptr = boundBytes.baseAddress!
            stream.src_size = self.count
            
            repeat {
                stream.dst_ptr = destinationBuffer
                stream.dst_size = bufferSize
                
                status = compression_stream_process(&stream, COMPRESSION_STREAM_FINALIZE)
                
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let processedBytes = bufferSize - stream.dst_size
                    output.append(destinationBuffer, count: processedBytes)
                    
                case COMPRESSION_STATUS_ERROR:
                    return
                    
                default:
                    break
                }
            } while status == COMPRESSION_STATUS_OK
        }
        
        guard status == COMPRESSION_STATUS_END else {
            throw CompressionError.compressionFailed("Compression failed with status: \(status)")
        }
        
        // For GZIP format, add proper header and footer
        if algorithm == .gzip && operation == .compression {
            return wrapWithGzipHeader(output)
        }
        
        return output
    }
    
    /// Wrap compressed data with GZIP header and footer
    private func wrapWithGzipHeader(_ compressedData: Data) -> Data {
        var result = Data()
        
        // GZIP header
        result.append(contentsOf: [0x1f, 0x8b]) // Magic number
        result.append(0x08) // Compression method (deflate)
        result.append(0x00) // Flags
        result.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Timestamp
        result.append(0x00) // Extra flags
        result.append(0xff) // OS (unknown)
        
        // Compressed data
        result.append(compressedData)
        
        // CRC32 and size (simplified - in production, calculate actual CRC)
        let crc32 = self.crc32()
        result.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Array($0) })
        result.append(contentsOf: withUnsafeBytes(of: UInt32(self.count).littleEndian) { Array($0) })
        
        return result
    }
    
    /// Simple CRC32 calculation
    private func crc32() -> UInt32 {
        var crc: UInt32 = 0xffffffff
        
        for byte in self {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
            }
        }
        
        return ~crc
    }
}

// Fix for NSData compression
extension NSData {
    public enum CompressionAlgorithm: Int {
        case zlib
        case gzip
    }
    
    public func compressed(using algorithm: CompressionAlgorithm) -> NSData? {
        do {
            let data = self as Data
            let compressed = try data.compress(using: algorithm == .gzip ? .gzip : .zlib)
            return compressed as NSData
        } catch {
            return nil
        }
    }
    
    public func decompressed(using algorithm: CompressionAlgorithm) -> NSData? {
        do {
            let data = self as Data
            let decompressed = try data.decompress(using: algorithm == .gzip ? .gzip : .zlib)
            return decompressed as NSData
        } catch {
            return nil
        }
    }
}