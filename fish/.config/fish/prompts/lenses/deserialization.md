Deserialization lens. Untrusted-input deserialization leading to remote code execution. JVM-focused, but the pattern applies to any language with a gadget-capable deserializer.

HARD GATE: a finding needs BOTH a deserializer call site AND a data-flow path from untrusted input to it. Deserializing your own freshly-serialized data, or data signed/HMAC'd before serialization and verified before deserialization, is NOT a finding.

Where to look first (non-exhaustive — reason beyond this list):
- Java native: `ObjectInputStream.readObject` on request/queue/file bytes.
- Jackson polymorphic default-typing (`enableDefaultTyping`, `@JsonTypeInfo` with a broad base type).
- XStream / `XMLDecoder` on untrusted XML.
- SnakeYAML `Yaml.load` without a restricted constructor.
- Kryo / Hessian / other binary serializers reading untrusted input.
- Mitigation-bypass: an `ObjectInputFilter`/allow-list that still admits a known gadget class.
