namespace PortKiller.Models;

public enum CloudflaredProtocol
{
    Http2,
    Quic
}

public static class CloudflaredProtocolExtensions
{
    public static string ToArgument(this CloudflaredProtocol protocol)
    {
        return protocol == CloudflaredProtocol.Quic ? "quic" : "http2";
    }

    public static string ToDisplayName(this CloudflaredProtocol protocol)
    {
        return protocol == CloudflaredProtocol.Quic ? "QUIC" : "HTTP/2";
    }

    public static CloudflaredProtocol FromString(string? value)
    {
        return string.Equals(value, "quic", System.StringComparison.OrdinalIgnoreCase)
            ? CloudflaredProtocol.Quic
            : CloudflaredProtocol.Http2;
    }
}
