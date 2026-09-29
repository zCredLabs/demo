// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CborDecoder
 * @notice Pure-Solidity CBOR (RFC 8949) and COSE_Sign1 (RFC 9052) binary decoder.
 * @dev Specifically optimized for AWS Nitro Enclave remote attestation documents.
 */
library CborDecoder {
    error CborInvalidHeader(uint256 offset);
    error CborOutOfBounds(uint256 requested, uint256 available);
    error CborUnexpectedMajorType(uint8 expected, uint8 actual);
    error CborUnsupportedMajorType(uint8 majorType);
    error CoseInvalidEnvelope(string reason);

    // Major Types (RFC 8949 §3.1)
    uint8 internal constant MAJOR_UINT = 0;
    uint8 internal constant MAJOR_NINT = 1;
    uint8 internal constant MAJOR_BSTR = 2;
    uint8 internal constant MAJOR_TSTR = 3;
    uint8 internal constant MAJOR_ARRAY = 4;
    uint8 internal constant MAJOR_MAP = 5;
    uint8 internal constant MAJOR_TAG = 6;
    uint8 internal constant MAJOR_SIMPLE = 7;

    struct DecodedItem {
        uint8 majorType;
        uint64 value;
        uint256 contentOffset;
        uint256 nextOffset;
    }

    struct NitroAttestation {
        string moduleId;
        string digest;
        uint64 timestamp; // ms since epoch
        bytes pcr0;       // 48 bytes (SHA-384)
        bytes pcr1;
        bytes pcr2;
        bytes certificate; // DER leaf certificate
        bytes[] caBundle;   // Intermediate CA certificates
        bytes publicKey;   // Enclave public key
        bytes userData;    // Bound user data (ephemeral secp256k1 address or commitment)
        bytes nonce;       // Replay nonce
        bytes signature;   // Hardware COSE signature
    }

    /**
     * @notice Decodes the CBOR header at `offset`.
     * @param data The raw CBOR bytes.
     * @param offset Byte position to decode from.
     * @return item The decoded item descriptor.
     */
    function decodeHeader(bytes memory data, uint256 offset)
        internal
        pure
        returns (DecodedItem memory item)
    {
        if (offset >= data.length) {
            revert CborOutOfBounds(offset, data.length);
        }

        uint8 initialByte = uint8(data[offset]);
        item.majorType = initialByte >> 5;
        uint8 info = initialByte & 0x1F;

        if (info < 24) {
            item.value = info;
            item.contentOffset = offset + 1;
            item.nextOffset = offset + 1;
        } else if (info == 24) {
            if (offset + 1 >= data.length) revert CborOutOfBounds(offset + 1, data.length);
            item.value = uint8(data[offset + 1]);
            item.contentOffset = offset + 2;
            item.nextOffset = offset + 2;
        } else if (info == 25) {
            if (offset + 2 >= data.length) revert CborOutOfBounds(offset + 2, data.length);
            item.value = (uint64(uint8(data[offset + 1])) << 8) | uint64(uint8(data[offset + 2]));
            item.contentOffset = offset + 3;
            item.nextOffset = offset + 3;
        } else if (info == 26) {
            if (offset + 4 >= data.length) revert CborOutOfBounds(offset + 4, data.length);
            uint32 v;
            for (uint256 i = 0; i < 4; i++) {
                v = (v << 8) | uint8(data[offset + 1 + i]);
            }
            item.value = v;
            item.contentOffset = offset + 5;
            item.nextOffset = offset + 5;
        } else if (info == 27) {
            if (offset + 8 >= data.length) revert CborOutOfBounds(offset + 8, data.length);
            uint64 v;
            for (uint256 i = 0; i < 8; i++) {
                v = (v << 8) | uint8(data[offset + 1 + i]);
            }
            item.value = v;
            item.contentOffset = offset + 9;
            item.nextOffset = offset + 9;
        } else {
            revert CborUnsupportedMajorType(item.majorType);
        }

        // For bytes and strings, the value is the byte length, so nextOffset jumps past content
        if (item.majorType == MAJOR_BSTR || item.majorType == MAJOR_TSTR) {
            item.nextOffset = item.contentOffset + item.value;
            if (item.nextOffset > data.length) {
                revert CborOutOfBounds(item.nextOffset, data.length);
            }
        }
    }

    /**
     * @notice Extracts raw bytes from a Byte String (Major 2) or Text String (Major 3).
     */
    function extractBytes(bytes memory data, DecodedItem memory item)
        internal
        pure
        returns (bytes memory result)
    {
        uint256 len = uint256(item.value);
        result = new bytes(len);
        uint256 src = item.contentOffset;
        for (uint256 i = 0; i < len; i++) {
            result[i] = data[src + i];
        }
    }

    /**
     * @notice Extracts string from a Text String (Major 3).
     */
    function extractString(bytes memory data, DecodedItem memory item)
        internal
        pure
        returns (string memory)
    {
        return string(extractBytes(data, item));
    }

    /**
     * @notice Compares a CBOR text slice to a string literal.
     */
    function equalsString(
        bytes memory data,
        DecodedItem memory item,
        string memory expected
    ) internal pure returns (bool) {
        bytes memory expBytes = bytes(expected);
        if (item.value != expBytes.length) return false;
        uint256 src = item.contentOffset;
        for (uint256 i = 0; i < expBytes.length; i++) {
            if (data[src + i] != expBytes[i]) return false;
        }
        return true;
    }

    /**
     * @notice Unpacks a COSE_Sign1 structure [protected, unprotected, payload, signature].
     * @dev Supports Tag 18 (0xD2) or untagged 4-element CBOR array.
     */
    function parseCoseSign1(bytes memory coseDoc)
        internal
        pure
        returns (
            bytes memory protectedHeader,
            bytes memory unprotectedHeader,
            bytes memory payload,
            bytes memory signature
        )
    {
        uint256 offset = 0;
        DecodedItem memory item = decodeHeader(coseDoc, offset);

        // Optional Tag 18 (COSE_Sign1, 0xD2)
        if (item.majorType == MAJOR_TAG) {
            if (item.value != 18) {
                revert CoseInvalidEnvelope("Expected COSE_Sign1 Tag 18");
            }
            offset = item.contentOffset;
            item = decodeHeader(coseDoc, offset);
        }

        // Must be an Array of 4 elements: [protected, unprotected, payload, signature]
        if (item.majorType != MAJOR_ARRAY || item.value != 4) {
            revert CoseInvalidEnvelope("Expected 4-element array in COSE_Sign1");
        }

        offset = item.contentOffset;

        // Element 1: Protected Header (Byte String)
        DecodedItem memory protItem = decodeHeader(coseDoc, offset);
        if (protItem.majorType != MAJOR_BSTR) {
            revert CoseInvalidEnvelope("Protected header must be bstr");
        }
        protectedHeader = extractBytes(coseDoc, protItem);
        offset = protItem.nextOffset;

        // Element 2: Unprotected Header (Map)
        DecodedItem memory unprotItem = decodeHeader(coseDoc, offset);
        if (unprotItem.majorType != MAJOR_MAP) {
            revert CoseInvalidEnvelope("Unprotected header must be map");
        }
        uint256 unprotStart = offset;
        offset = skipItem(coseDoc, unprotItem);
        uint256 unprotLen = offset - unprotStart;
        unprotectedHeader = new bytes(unprotLen);
        for (uint256 u = 0; u < unprotLen; u++) {
            unprotectedHeader[u] = coseDoc[unprotStart + u];
        }

        // Element 3: Payload (Byte String containing CBOR attestation document)
        DecodedItem memory payloadItem = decodeHeader(coseDoc, offset);
        if (payloadItem.majorType != MAJOR_BSTR) {
            revert CoseInvalidEnvelope("Payload must be bstr");
        }
        payload = extractBytes(coseDoc, payloadItem);
        offset = payloadItem.nextOffset;

        // Element 4: Signature (Byte String)
        DecodedItem memory sigItem = decodeHeader(coseDoc, offset);
        if (sigItem.majorType != MAJOR_BSTR) {
            revert CoseInvalidEnvelope("Signature must be bstr");
        }
        signature = extractBytes(coseDoc, sigItem);
    }

    /**
     * @notice Parses the CBOR-encoded AWS Nitro Attestation Document payload.
     * @param payload The raw payload bytes from COSE_Sign1.
     * @return att The parsed NitroAttestation record.
     */
    function parseNitroPayload(bytes memory payload)
        internal
        pure
        returns (NitroAttestation memory att)
    {
        uint256 offset = 0;
        DecodedItem memory root = decodeHeader(payload, offset);
        if (root.majorType != MAJOR_MAP) {
            revert CoseInvalidEnvelope("Payload must be CBOR Map");
        }

        uint256 numPairs = uint256(root.value);
        offset = root.contentOffset;

        for (uint256 i = 0; i < numPairs; i++) {
            // Read Key (Text String)
            DecodedItem memory keyItem = decodeHeader(payload, offset);
            offset = keyItem.nextOffset;

            // Read Value Item header
            DecodedItem memory valItem = decodeHeader(payload, offset);

            if (equalsString(payload, keyItem, "module_id")) {
                att.moduleId = extractString(payload, valItem);
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "digest")) {
                att.digest = extractString(payload, valItem);
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "timestamp")) {
                att.timestamp = valItem.value;
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "certificate")) {
                att.certificate = extractBytes(payload, valItem);
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "public_key")) {
                att.publicKey = extractBytes(payload, valItem);
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "user_data")) {
                att.userData = extractBytes(payload, valItem);
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "nonce")) {
                att.nonce = extractBytes(payload, valItem);
                offset = valItem.nextOffset;
            } else if (equalsString(payload, keyItem, "pcrs")) {
                // Parse PCRs map
                offset = parsePcrs(payload, valItem, att);
            } else if (equalsString(payload, keyItem, "cabundle")) {
                // Parse CA Bundle array
                offset = parseCaBundle(payload, valItem, att);
            } else {
                // Skip unknown key-value pair
                offset = skipItem(payload, valItem);
            }
        }
    }

    /**
     * @notice Parses the PCRs map (int 0, 1, 2 => bstr).
     */
    function parsePcrs(
        bytes memory payload,
        DecodedItem memory mapItem,
        NitroAttestation memory att
    ) internal pure returns (uint256 nextOffset) {
        if (mapItem.majorType != MAJOR_MAP) {
            revert CoseInvalidEnvelope("pcrs must be CBOR Map");
        }
        uint256 pairs = uint256(mapItem.value);
        uint256 offset = mapItem.contentOffset;

        for (uint256 i = 0; i < pairs; i++) {
            DecodedItem memory pcrIndexItem = decodeHeader(payload, offset);
            offset = pcrIndexItem.nextOffset;

            DecodedItem memory pcrValItem = decodeHeader(payload, offset);
            bytes memory pcrBytes = extractBytes(payload, pcrValItem);
            offset = pcrValItem.nextOffset;

            if (pcrIndexItem.value == 0) {
                att.pcr0 = pcrBytes;
            } else if (pcrIndexItem.value == 1) {
                att.pcr1 = pcrBytes;
            } else if (pcrIndexItem.value == 2) {
                att.pcr2 = pcrBytes;
            }
        }
        return offset;
    }

    /**
     * @notice Parses the cabundle array of DER certificate byte strings.
     */
    function parseCaBundle(
        bytes memory payload,
        DecodedItem memory arrayItem,
        NitroAttestation memory att
    ) internal pure returns (uint256 nextOffset) {
        if (arrayItem.majorType != MAJOR_ARRAY) {
            revert CoseInvalidEnvelope("cabundle must be CBOR Array");
        }
        uint256 count = uint256(arrayItem.value);
        att.caBundle = new bytes[](count);
        uint256 offset = arrayItem.contentOffset;

        for (uint256 i = 0; i < count; i++) {
            DecodedItem memory certItem = decodeHeader(payload, offset);
            att.caBundle[i] = extractBytes(payload, certItem);
            offset = certItem.nextOffset;
        }
        return offset;
    }

    /**
     * @notice Skips a CBOR item and its children.
     */
    function skipItem(bytes memory data, DecodedItem memory item)
        internal
        pure
        returns (uint256 nextOffset)
    {
        if (item.majorType == MAJOR_UINT || item.majorType == MAJOR_NINT || item.majorType == MAJOR_SIMPLE) {
            return item.nextOffset;
        }
        if (item.majorType == MAJOR_BSTR || item.majorType == MAJOR_TSTR) {
            return item.nextOffset;
        }
        if (item.majorType == MAJOR_ARRAY) {
            uint256 off = item.contentOffset;
            for (uint256 i = 0; i < item.value; i++) {
                DecodedItem memory child = decodeHeader(data, off);
                off = skipItem(data, child);
            }
            return off;
        }
        if (item.majorType == MAJOR_MAP) {
            uint256 off = item.contentOffset;
            for (uint256 i = 0; i < item.value; i++) {
                // Key
                DecodedItem memory k = decodeHeader(data, off);
                off = skipItem(data, k);
                // Value
                DecodedItem memory v = decodeHeader(data, off);
                off = skipItem(data, v);
            }
            return off;
        }
        if (item.majorType == MAJOR_TAG) {
            DecodedItem memory child = decodeHeader(data, item.contentOffset);
            return skipItem(data, child);
        }
        return item.nextOffset;
    }

    /**
     * @notice Convenience helper: Parses full COSE_Sign1 document into NitroAttestation.
     */
    function parseNitroDocument(bytes memory coseDoc)
        internal
        pure
        returns (NitroAttestation memory att)
    {
        (, , bytes memory payload, bytes memory signature) = parseCoseSign1(coseDoc);
        att = parseNitroPayload(payload);
        att.signature = signature;
    }
}
