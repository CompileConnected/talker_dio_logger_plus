/// Content type enumeration for HTTP responses.
///
/// Represents the *logical* kind of content so the logger can pick the right
/// display / storage strategy. Only types that the logger can actually render.
/// Everything else (video, audio, binary, etc.) falls under [unknown].
enum HttpBodyType { json, html, xml, text, image, unknown }
