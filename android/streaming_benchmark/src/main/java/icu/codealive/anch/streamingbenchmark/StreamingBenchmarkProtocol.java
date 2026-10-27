package icu.codealive.anch.streamingbenchmark;

import android.content.ContentResolver;
import android.net.Uri;
import android.os.SystemClock;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import javax.crypto.Cipher;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.PBEKeySpec;
import javax.crypto.spec.SecretKeySpec;

final class BenchmarkProgress {
    final String stage;
    final long completedBytes;
    final long totalBytes;

    BenchmarkProgress(String stage, long completedBytes, long totalBytes) {
        this.stage = stage;
        this.completedBytes = completedBytes;
        this.totalBytes = totalBytes;
    }
}

final class StreamingBenchmarkResult {
    final long exportMillis;
    final long readVerifyMillis;
    final long stagingMillis;
    final String totalMiB;

    StreamingBenchmarkResult(long totalBytes, long exportMillis, long readVerifyMillis, long stagingMillis) {
        this.exportMillis = exportMillis;
        this.readVerifyMillis = readVerifyMillis;
        this.stagingMillis = stagingMillis;
        this.totalMiB = String.format(java.util.Locale.ROOT, "%.1f", totalBytes / (1024.0 * 1024.0));
    }
}

final class BenchmarkCancelledException extends Exception {
}

/**
 * 独立真机基准容器，不是安册生产备份格式，也不兼容生产 V1。
 *
 * 每帧均用独立 AES-GCM 认证，最后必须存在经认证的提交帧；任一截断、
 * 顺序错误或认证失败都会被读回验证阻断。密钥仅在本轮进程内存中生成和使用。
 */
final class StreamingBenchmarkProtocol {
    private static final int MAGIC = 0x414E4348;
    private static final int VERSION = 1;
    private static final int CHUNK_BYTES = 256 * 1024;
    private static final int TAG_BYTES = 16;
    private static final int FINAL_MARKER = -1;
    private static final int PBKDF2_ITERATIONS = 210000;
    private static final int SALT_BYTES = 16;
    private static final int NONCE_BYTES = 12;
    private static final int DIGEST_BYTES = 32;
    private static final int COMMIT_PAYLOAD_BYTES = 8 + 4 + DIGEST_BYTES;

    private StreamingBenchmarkProtocol() {
    }

    static StreamingBenchmarkResult run(
        ContentResolver resolver,
        Uri targetUri,
        long totalBytes,
        BooleanSupplier isCancelled,
        Consumer<BenchmarkProgress> onProgress
    ) throws Exception {
        if (totalBytes <= 0) {
            throw new IllegalArgumentException("基准字节数非法");
        }
        KeyMaterial keyMaterial = deriveEphemeralKey();
        try {
            checkCancelled(isCancelled);
            byte[] baseNonce = randomBytes(NONCE_BYTES);
            int frameCount = expectedFrameCount(totalBytes);

            long exportStartedAt = SystemClock.elapsedRealtime();
            OutputStream rawOutput = resolver.openOutputStream(targetUri, "w");
            if (rawOutput == null) {
                throw new IllegalStateException("输出流不可用");
            }
            try (DataOutputStream output = new DataOutputStream(new BufferedOutputStream(rawOutput, CHUNK_BYTES))) {
                writeHeader(output, totalBytes, frameCount, keyMaterial.salt, baseNonce);
                writeFrames(
                    output,
                    keyMaterial.key,
                    baseNonce,
                    totalBytes,
                    frameCount,
                    isCancelled,
                    onProgress
                );
                output.flush();
            }
            long exportMillis = SystemClock.elapsedRealtime() - exportStartedAt;

            long readVerifyStartedAt = SystemClock.elapsedRealtime();
            VerifiedStream verified = readAndVerify(
                resolver,
                targetUri,
                keyMaterial.key,
                totalBytes,
                "正在读回校验",
                isCancelled,
                onProgress
            );
            long readVerifyMillis = SystemClock.elapsedRealtime() - readVerifyStartedAt;

            long stagingStartedAt = SystemClock.elapsedRealtime();
            VerifiedStream staged = readAndVerify(
                resolver,
                targetUri,
                keyMaterial.key,
                totalBytes,
                "正在模拟 staging",
                isCancelled,
                onProgress
            );
            long stagingMillis = SystemClock.elapsedRealtime() - stagingStartedAt;

            if (verified.totalBytes != staged.totalBytes ||
                !MessageDigest.isEqual(verified.digest, staged.digest)) {
                throw new IllegalStateException("staging 模拟校验不一致");
            }
            return new StreamingBenchmarkResult(totalBytes, exportMillis, readVerifyMillis, stagingMillis);
        } catch (BenchmarkCancelledException cancelled) {
            assertIncompleteStreamIsRejected(resolver, targetUri, keyMaterial.key, totalBytes);
            throw cancelled;
        } finally {
            keyMaterial.clear();
        }
    }

    private static void writeFrames(
        DataOutputStream output,
        SecretKeySpec key,
        byte[] baseNonce,
        long totalBytes,
        int frameCount,
        BooleanSupplier isCancelled,
        Consumer<BenchmarkProgress> onProgress
    ) throws Exception {
        byte[] plaintext = new byte[CHUNK_BYTES];
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        long offset = 0;

        for (int frameIndex = 0; frameIndex < frameCount; frameIndex++) {
            checkCancelled(isCancelled);
            int plainLength = (int) Math.min(CHUNK_BYTES, totalBytes - offset);
            fillVirtualBytes(plaintext, plainLength, offset);
            digest.update(plaintext, 0, plainLength);

            byte[] encrypted = crypt(
                Cipher.ENCRYPT_MODE,
                key,
                nonceFor(baseNonce, frameIndex),
                frameAad(frameIndex, totalBytes, plainLength),
                plaintext,
                plainLength
            );
            output.writeInt(frameIndex);
            output.writeInt(plainLength);
            output.writeInt(encrypted.length);
            output.write(encrypted);

            offset += plainLength;
            onProgress.accept(new BenchmarkProgress("正在流式导出", offset, totalBytes));
        }

        checkCancelled(isCancelled);
        byte[] commitPayload = buildCommitPayload(totalBytes, frameCount, digest.digest());
        byte[] finalFrame = crypt(
            Cipher.ENCRYPT_MODE,
            key,
            nonceFor(baseNonce, frameCount),
            finalAad(totalBytes, frameCount),
            commitPayload,
            commitPayload.length
        );
        output.writeInt(FINAL_MARKER);
        output.writeInt(finalFrame.length);
        output.write(finalFrame);
    }

    private static VerifiedStream readAndVerify(
        ContentResolver resolver,
        Uri sourceUri,
        SecretKeySpec key,
        long expectedTotalBytes,
        String stage,
        BooleanSupplier isCancelled,
        Consumer<BenchmarkProgress> onProgress
    ) throws Exception {
        InputStream rawInput = resolver.openInputStream(sourceUri);
        if (rawInput == null) {
            throw new IllegalStateException("输入流不可用");
        }
        try (DataInputStream input = new DataInputStream(new BufferedInputStream(rawInput, CHUNK_BYTES))) {
            StreamHeader header = readHeader(input);
            if (header.totalBytes != expectedTotalBytes ||
                header.frameCount != expectedFrameCount(expectedTotalBytes)) {
                throw new IllegalStateException("基准文件大小与本轮不一致");
            }

            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            long offset = 0;
            for (int expectedIndex = 0; expectedIndex < header.frameCount; expectedIndex++) {
                checkCancelled(isCancelled);
                int frameIndex = input.readInt();
                int plainLength = input.readInt();
                int cipherLength = input.readInt();
                int expectedLength = (int) Math.min(CHUNK_BYTES, header.totalBytes - offset);
                if (frameIndex != expectedIndex || plainLength != expectedLength ||
                    cipherLength != plainLength + TAG_BYTES) {
                    throw new IllegalStateException("分帧顺序或长度校验失败");
                }
                byte[] ciphertext = new byte[cipherLength];
                input.readFully(ciphertext);
                byte[] plaintext = crypt(
                    Cipher.DECRYPT_MODE,
                    key,
                    nonceFor(header.baseNonce, frameIndex),
                    frameAad(frameIndex, header.totalBytes, plainLength),
                    ciphertext,
                    ciphertext.length
                );
                if (plaintext.length != plainLength) {
                    throw new IllegalStateException("分帧解密长度校验失败");
                }
                digest.update(plaintext);
                offset += plainLength;
                onProgress.accept(new BenchmarkProgress(stage, offset, header.totalBytes));
            }

            checkCancelled(isCancelled);
            int marker = input.readInt();
            int finalCipherLength = input.readInt();
            if (marker != FINAL_MARKER || finalCipherLength != COMMIT_PAYLOAD_BYTES + TAG_BYTES) {
                throw new IllegalStateException("缺少最终提交帧");
            }
            byte[] finalCiphertext = new byte[finalCipherLength];
            input.readFully(finalCiphertext);
            byte[] commitPayload = crypt(
                Cipher.DECRYPT_MODE,
                key,
                nonceFor(header.baseNonce, header.frameCount),
                finalAad(header.totalBytes, header.frameCount),
                finalCiphertext,
                finalCiphertext.length
            );
            CommitPayload committed = parseCommitPayload(commitPayload);
            byte[] calculatedDigest = digest.digest();
            if (committed.totalBytes != header.totalBytes ||
                committed.frameCount != header.frameCount ||
                !MessageDigest.isEqual(committed.digest, calculatedDigest) ||
                input.read() != -1) {
                throw new IllegalStateException("最终提交帧校验失败");
            }
            return new VerifiedStream(offset, calculatedDigest);
        }
    }

    private static void assertIncompleteStreamIsRejected(
        ContentResolver resolver,
        Uri sourceUri,
        SecretKeySpec key,
        long expectedTotalBytes
    ) throws Exception {
        boolean rejected = false;
        try {
            readAndVerify(
                resolver,
                sourceUri,
                key,
                expectedTotalBytes,
                "正在验证中断文件",
                () -> false,
                ignored -> { }
            );
        } catch (Exception ignored) {
            rejected = true;
        }
        if (!rejected) {
            throw new IllegalStateException("中断文件意外通过完整性校验");
        }
    }

    private static void writeHeader(
        DataOutputStream output,
        long totalBytes,
        int frameCount,
        byte[] salt,
        byte[] baseNonce
    ) throws Exception {
        output.writeInt(MAGIC);
        output.writeInt(VERSION);
        output.writeInt(CHUNK_BYTES);
        output.writeLong(totalBytes);
        output.writeInt(frameCount);
        output.write(salt);
        output.write(baseNonce);
    }

    private static StreamHeader readHeader(DataInputStream input) throws Exception {
        if (input.readInt() != MAGIC || input.readInt() != VERSION || input.readInt() != CHUNK_BYTES) {
            throw new IllegalStateException("基准文件头校验失败");
        }
        long totalBytes = input.readLong();
        int frameCount = input.readInt();
        if (totalBytes <= 0 || frameCount <= 0 || frameCount != expectedFrameCount(totalBytes)) {
            throw new IllegalStateException("基准文件头长度非法");
        }
        byte[] salt = new byte[SALT_BYTES];
        byte[] baseNonce = new byte[NONCE_BYTES];
        input.readFully(salt);
        input.readFully(baseNonce);
        Arrays.fill(salt, (byte) 0);
        return new StreamHeader(totalBytes, frameCount, baseNonce);
    }

    private static byte[] buildCommitPayload(long totalBytes, int frameCount, byte[] digest) {
        byte[] payload = new byte[COMMIT_PAYLOAD_BYTES];
        writeLong(payload, 0, totalBytes);
        writeInt(payload, 8, frameCount);
        System.arraycopy(digest, 0, payload, 12, DIGEST_BYTES);
        return payload;
    }

    private static CommitPayload parseCommitPayload(byte[] payload) {
        if (payload.length != COMMIT_PAYLOAD_BYTES) {
            throw new IllegalStateException("最终提交帧长度非法");
        }
        return new CommitPayload(
            readLong(payload, 0),
            readInt(payload, 8),
            Arrays.copyOfRange(payload, 12, COMMIT_PAYLOAD_BYTES)
        );
    }

    private static byte[] crypt(
        int mode,
        SecretKeySpec key,
        byte[] nonce,
        byte[] aad,
        byte[] input,
        int inputLength
    ) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(mode, key, new GCMParameterSpec(128, nonce));
        cipher.updateAAD(aad);
        return cipher.doFinal(input, 0, inputLength);
    }

    private static byte[] frameAad(int frameIndex, long totalBytes, int plainLength) {
        byte[] aad = new byte[16];
        writeInt(aad, 0, frameIndex);
        writeLong(aad, 4, totalBytes);
        writeInt(aad, 12, plainLength);
        return aad;
    }

    private static byte[] finalAad(long totalBytes, int frameCount) {
        byte[] aad = new byte[16];
        writeInt(aad, 0, FINAL_MARKER);
        writeLong(aad, 4, totalBytes);
        writeInt(aad, 12, frameCount);
        return aad;
    }

    private static byte[] nonceFor(byte[] baseNonce, int sequence) {
        byte[] nonce = baseNonce.clone();
        writeInt(nonce, 8, sequence);
        return nonce;
    }

    private static int expectedFrameCount(long totalBytes) {
        long count = (totalBytes + CHUNK_BYTES - 1) / CHUNK_BYTES;
        if (count < 1 || count > Integer.MAX_VALUE) {
            throw new IllegalArgumentException("分帧数量非法");
        }
        return (int) count;
    }

    private static KeyMaterial deriveEphemeralKey() throws Exception {
        SecureRandom random = new SecureRandom();
        char[] generatedPassphrase = new char[32];
        for (int index = 0; index < generatedPassphrase.length; index++) {
            generatedPassphrase[index] = (char) ('a' + random.nextInt(26));
        }
        byte[] salt = new byte[SALT_BYTES];
        random.nextBytes(salt);
        PBEKeySpec spec = new PBEKeySpec(generatedPassphrase, salt, PBKDF2_ITERATIONS, 256);
        try {
            byte[] keyBytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();
            try {
                return new KeyMaterial(new SecretKeySpec(keyBytes, "AES"), salt);
            } finally {
                Arrays.fill(keyBytes, (byte) 0);
            }
        } finally {
            spec.clearPassword();
            Arrays.fill(generatedPassphrase, '\u0000');
        }
    }

    private static byte[] randomBytes(int size) {
        byte[] bytes = new byte[size];
        new SecureRandom().nextBytes(bytes);
        return bytes;
    }

    private static void fillVirtualBytes(byte[] target, int length, long offset) {
        long state = offset ^ 0x6a09e667f3bcc909L;
        for (int index = 0; index < length; index++) {
            state ^= state << 13;
            state ^= state >>> 7;
            state ^= state << 17;
            target[index] = (byte) state;
        }
    }

    private static void checkCancelled(BooleanSupplier isCancelled) throws BenchmarkCancelledException {
        if (isCancelled.getAsBoolean()) {
            throw new BenchmarkCancelledException();
        }
    }

    private static void writeInt(byte[] target, int offset, int value) {
        target[offset] = (byte) (value >>> 24);
        target[offset + 1] = (byte) (value >>> 16);
        target[offset + 2] = (byte) (value >>> 8);
        target[offset + 3] = (byte) value;
    }

    private static void writeLong(byte[] target, int offset, long value) {
        for (int index = 0; index < 8; index++) {
            target[offset + index] = (byte) (value >>> ((7 - index) * 8));
        }
    }

    private static int readInt(byte[] source, int offset) {
        return ((source[offset] & 0xff) << 24)
            | ((source[offset + 1] & 0xff) << 16)
            | ((source[offset + 2] & 0xff) << 8)
            | (source[offset + 3] & 0xff);
    }

    private static long readLong(byte[] source, int offset) {
        long value = 0;
        for (int index = 0; index < 8; index++) {
            value = (value << 8) | (source[offset + index] & 0xffL);
        }
        return value;
    }

    private static final class KeyMaterial {
        final SecretKeySpec key;
        final byte[] salt;

        KeyMaterial(SecretKeySpec key, byte[] salt) {
            this.key = key;
            this.salt = salt;
        }

        void clear() {
            Arrays.fill(salt, (byte) 0);
        }
    }

    private static final class StreamHeader {
        final long totalBytes;
        final int frameCount;
        final byte[] baseNonce;

        StreamHeader(long totalBytes, int frameCount, byte[] baseNonce) {
            this.totalBytes = totalBytes;
            this.frameCount = frameCount;
            this.baseNonce = baseNonce;
        }
    }

    private static final class CommitPayload {
        final long totalBytes;
        final int frameCount;
        final byte[] digest;

        CommitPayload(long totalBytes, int frameCount, byte[] digest) {
            this.totalBytes = totalBytes;
            this.frameCount = frameCount;
            this.digest = digest;
        }
    }

    private static final class VerifiedStream {
        final long totalBytes;
        final byte[] digest;

        VerifiedStream(long totalBytes, byte[] digest) {
            this.totalBytes = totalBytes;
            this.digest = digest;
        }
    }
}
