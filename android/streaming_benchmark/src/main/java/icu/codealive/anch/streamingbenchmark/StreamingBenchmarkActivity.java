package icu.codealive.anch.streamingbenchmark;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public final class StreamingBenchmarkActivity extends Activity {
    private static final int CREATE_DOCUMENT_REQUEST_CODE = 9401;
    private static final long MIB = 1024L * 1024L;

    private static final BenchmarkProfile[] PROFILES = {
        new BenchmarkProfile("20MiB", 20 * MIB),
        new BenchmarkProfile("50MiB", 50 * MIB),
        new BenchmarkProfile("100MiB", 100 * MIB),
    };

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final AtomicBoolean cancelRequested = new AtomicBoolean(false);

    private TextView statusView;
    private ProgressBar progressBar;
    private Button cancelButton;
    private List<Button> profileButtons;
    private Long pendingBytes;
    private boolean benchmarkRunning;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle("安册流式备份基准");
        setContentView(buildContentView());
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != CREATE_DOCUMENT_REQUEST_CODE) {
            return;
        }

        Long bytes = pendingBytes;
        pendingBytes = null;
        if (bytes == null) {
            return;
        }
        Uri uri = data == null ? null : data.getData();
        if (resultCode != RESULT_OK || uri == null) {
            renderIdle("已取消。未开始写入虚构基准数据。");
            return;
        }
        startBenchmark(uri, bytes);
    }

    @Override
    protected void onStop() {
        super.onStop();
        if (benchmarkRunning) {
            cancelRequested.set(true);
        }
    }

    @Override
    protected void onDestroy() {
        cancelRequested.set(true);
        executor.shutdownNow();
        super.onDestroy();
    }

    private View buildContentView() {
        int padding = (int) (24 * getResources().getDisplayMetrics().density);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(padding, padding, padding, padding);

        TextView title = new TextView(this);
        title.setText("安册流式备份基准");
        title.setTextSize(24f);
        root.addView(title);

        TextView description = new TextView(this);
        description.setText("仅生成虚构字节，不读取安册资料、附件、PIN 或备份密码。导出后会从系统选择的位置读回，逐帧验证并执行无落盘的 staging 模拟。");
        description.setTextSize(16f);
        description.setPadding(0, padding / 2, 0, padding / 2);
        root.addView(description);

        progressBar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progressBar.setMax(1000);
        progressBar.setIndeterminate(false);
        root.addView(progressBar, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        statusView = new TextView(this);
        statusView.setText("请选择虚构数据档位。");
        statusView.setTextSize(16f);
        statusView.setPadding(0, padding / 2, 0, padding / 2);
        root.addView(statusView);

        profileButtons = new ArrayList<>();
        for (BenchmarkProfile profile : PROFILES) {
            Button button = new Button(this);
            button.setText("运行 " + profile.label);
            button.setOnClickListener(view -> requestDestination(profile));
            profileButtons.add(button);
            root.addView(button, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ));
        }

        cancelButton = new Button(this);
        cancelButton.setText("中断本轮");
        cancelButton.setVisibility(View.GONE);
        cancelButton.setOnClickListener(view -> cancelRequested.set(true));
        root.addView(cancelButton, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ));
        return root;
    }

    private void requestDestination(BenchmarkProfile profile) {
        if (benchmarkRunning || pendingBytes != null) {
            return;
        }
        pendingBytes = profile.bytes;
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("application/octet-stream");
        intent.putExtra(Intent.EXTRA_TITLE, "anch-streaming-benchmark-" + profile.label + ".abkbench");
        startActivityForResult(intent, CREATE_DOCUMENT_REQUEST_CODE);
    }

    private void startBenchmark(Uri uri, long bytes) {
        benchmarkRunning = true;
        cancelRequested.set(false);
        for (Button button : profileButtons) {
            button.setEnabled(false);
        }
        cancelButton.setVisibility(View.VISIBLE);
        updateProgress(new BenchmarkProgress("正在准备密钥派生", 0, bytes));

        executor.execute(() -> {
            try {
                StreamingBenchmarkResult result = StreamingBenchmarkProtocol.run(
                    getContentResolver(),
                    uri,
                    bytes,
                    cancelRequested::get,
                    this::updateProgress
                );
                runOnUiThread(() -> renderIdle(String.format(
                    Locale.ROOT,
                    "通过：%s MiB；导出 %d ms；读取校验 %d ms；staging 模拟 %d ms。",
                    result.totalMiB,
                    result.exportMillis,
                    result.readVerifyMillis,
                    result.stagingMillis
                )));
            } catch (BenchmarkCancelledException ignored) {
                runOnUiThread(() -> renderIdle("已安全中断。未写入最终提交帧的虚构文件不能通过读回验证。"));
            } catch (Exception ignored) {
                runOnUiThread(() -> renderIdle("安全失败。未确认成功，虚构文件不能作为有效备份使用。"));
            }
        });
    }

    private void updateProgress(BenchmarkProgress progress) {
        runOnUiThread(() -> {
            long completed = Math.max(0, Math.min(progress.completedBytes, progress.totalBytes));
            int value = progress.totalBytes == 0 ? 0 : (int) (completed * 1000 / progress.totalBytes);
            progressBar.setProgress(value);
            statusView.setText(
                progress.stage + "：" + formatMiB(completed) + " / " + formatMiB(progress.totalBytes)
            );
        });
    }

    private void renderIdle(String message) {
        benchmarkRunning = false;
        pendingBytes = null;
        cancelButton.setVisibility(View.GONE);
        for (Button button : profileButtons) {
            button.setEnabled(true);
        }
        statusView.setText(message);
    }

    private static String formatMiB(long bytes) {
        return String.format(Locale.ROOT, "%.1f MiB", bytes / (double) MIB);
    }

    private static final class BenchmarkProfile {
        final String label;
        final long bytes;

        BenchmarkProfile(String label, long bytes) {
            this.label = label;
            this.bytes = bytes;
        }
    }
}
