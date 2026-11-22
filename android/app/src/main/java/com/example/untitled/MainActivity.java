package com.caelis.pufftrack;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.pufftrack.app/icon";
    private static final String DEEPLINK_CHANNEL = "com.pufftrack.app/deeplink";
    private static final String[] ALIASES = {
        "com.caelis.pufftrack.MainActivityRed",
        "com.caelis.pufftrack.MainActivityDark",
        "com.caelis.pufftrack.MainActivityLight",
        "com.caelis.pufftrack.MainActivityGold"
    };

    private String initialDeepLink = null;
    private MethodChannel deeplinkMethodChannel = null;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        handleIncomingIntent(getIntent(), true);
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIncomingIntent(intent, false);
    }

    private void handleIncomingIntent(@Nullable Intent intent, boolean isInitial) {
        if (intent == null) return;
        if (Intent.ACTION_VIEW.equals(intent.getAction()) && intent.getDataString() != null) {
            String link = intent.getDataString();
            if (isInitial || deeplinkMethodChannel == null) {
                initialDeepLink = link;
            }
            if (deeplinkMethodChannel != null) {
                deeplinkMethodChannel.invokeMethod("onDeepLink", link);
            }
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("changeIcon")) {
                    String targetAlias = call.argument("alias");
                    changeAppIcon(targetAlias);
                    result.success(true);
                } else if (call.method.equals("restartApp")) {
                    restartApplication();
                    result.success(true);
                } else {
                    result.notImplemented();
                }
            });

        deeplinkMethodChannel = new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            DEEPLINK_CHANNEL
        );
        deeplinkMethodChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("getInitialLink")) {
                String link = initialDeepLink;
                initialDeepLink = null;
                result.success(link);
            } else {
                result.notImplemented();
            }
        });
    }

    private void changeAppIcon(String targetAlias) {
        Context context = getApplicationContext();
        PackageManager pm = context.getPackageManager();

        for (String alias : ALIASES) {
            ComponentName componentName = new ComponentName(context, alias);
            int newState = alias.equals(targetAlias)
                ? PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                : PackageManager.COMPONENT_ENABLED_STATE_DISABLED;
            pm.setComponentEnabledSetting(componentName, newState, PackageManager.DONT_KILL_APP);
        }
    }

    private void restartApplication() {
        Intent startMain = new Intent(Intent.ACTION_MAIN);
        startMain.addCategory(Intent.CATEGORY_HOME);
        startMain.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(startMain);
        System.exit(0);
    }
}
